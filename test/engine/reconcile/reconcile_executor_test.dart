/*
 * Copyright (c) 2026 Angelo Cassano
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use,
 * copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following
 * conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 */

import 'dart:io';

import 'package:flutter_flavorizr/src/engine/artifact.dart';
import 'package:flutter_flavorizr/src/engine/conflict/conflict_content.dart';
import 'package:flutter_flavorizr/src/engine/conflict/conflict_policy.dart';
import 'package:flutter_flavorizr/src/engine/conflict/conflict_resolver.dart';
import 'package:flutter_flavorizr/src/engine/execution_plan.dart';
import 'package:flutter_flavorizr/src/engine/flavorizr_context.dart';
import 'package:flutter_flavorizr/src/engine/flavorizr_processor.dart';
import 'package:flutter_flavorizr/src/engine/lock/flavorizr_lock.dart';
import 'package:flutter_flavorizr/src/engine/lock/lock_store.dart';
import 'package:flutter_flavorizr/src/engine/ownership.dart';
import 'package:flutter_flavorizr/src/engine/plan_executor.dart';
import 'package:flutter_flavorizr/src/engine/reconcile/reconciliation.dart';
import 'package:flutter_flavorizr/src/engine/resource.dart';
import 'package:flutter_flavorizr/src/engine/resource_key.dart';
import 'package:flutter_flavorizr/src/engine/shadow/file_digest.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mason_logger/mason_logger.dart';

import '../../test_utils.dart';
import '../conflict/conflict_fakes.dart';
import '../shadow/shadow_fixture.dart';

/// A processor that writes `<folder>/<flavor>.txt` for every flavor of
/// [flavors], and tracks it as a managed artifact.
class _PerFlavorProcessor extends FlavorizrProcessor {
  @override
  final String id;

  final String folder;
  final Iterable<String> flavors;
  final Set<ResourceKey<Object?>> needs;

  _PerFlavorProcessor(
    this.id,
    this.folder,
    this.flavors, {
    this.needs = const {},
  });

  @override
  Set<ResourceKey<Object?>> get requires => needs;

  @override
  Future<void> apply(FlavorizrContext ctx) async {
    for (final flavor in flavors) {
      final path = '$folder/$flavor.txt';

      File(ctx.resolve(path))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('$id $flavor');
      ctx.track(Artifact.managed(path));
    }
  }
}

/// A resource that tracks [path] from its teardown, on the context of the run:
/// no processor is attributed the artifact.
class _TeardownTracker extends Resource<String> {
  static const _key = ResourceKey<String>('teardown-tracker');

  final String path;

  const _TeardownTracker(this.path);

  @override
  ResourceKey<String> get key => _key;

  @override
  Future<String> setup(FlavorizrContext ctx) async => 'value';

  @override
  Future<void> teardown(
    FlavorizrContext ctx,
    String value, {
    required bool success,
  }) async {
    ctx.track(Artifact.managed(path));
  }
}

const _ids = {'android', 'ios'};

void main() {
  late ShadowFixture fixture;
  late LockStore store;

  setUp(() {
    fixture = ShadowFixture();
    store = LockStore(fixture.project.root, runningVersion: '3.0.0');
  });
  tearDown(() => fixture.dispose());

  /// A run of [requested] processors for [flavors], committing with the
  /// reconciliation the way the CLI will.
  Future<void> run(
    Iterable<String> requested, {
    required List<String> flavors,
    List<Resource<Object?>> resources = const [],
  }) async {
    final processors = [
      _PerFlavorProcessor(
        'android',
        'android',
        flavors,
        needs: {for (final resource in resources) resource.key},
      ),
      _PerFlavorProcessor('ios', 'ios', flavors),
    ];

    await PlanExecutor(logger: Logger(level: Level.quiet)).execute(
      resolveExecutionPlan(processors, requested: requested),
      config: TestUtils.parseFlavorizr('test_resources/pubspec'),
      projectRoot: fixture.project.root,
      paths: ['android', 'ios'],
      resources: resources,
      previousFlavors: (await store.read())?.flavorNames ?? const {},
      commit: (shadow, ctx) async {
        final previous = await store.read();
        final reconciliation = await reconcile(
          projectRoot: shadow.projectRoot,
          paths: shadow.paths,
          previous: previous,
          produced: ctx.trackedByProcessor,
          tracked: ctx.tracked,
          ownedHashes: {
            for (final artifact in ctx.tracked)
              artifact.path: digestOf(
                File(ctx.resolve(artifact.path)).readAsBytesSync(),
              ),
          },
          desiredFlavors: {for (final flavor in flavors) flavor: 'h-$flavor'},
          availableProcessors: _ids,
          flavorizrVersion: '3.0.0',
        );
        final diff = reconciliation.applyTo(
          await shadow.diff(
            tracked: ctx.tracked,
            recordedHashes: {
              for (final processor
                  in previous?.processors.values ?? <ProcessorLock>[])
                for (final entry in processor.files.entries)
                  if (entry.value.hash != null) entry.key: entry.value.hash!,
            },
          ),
        );
        final resolution = await ConflictResolver(
          terminal: FakeTerminal(isInteractive: false),
          content: reconciliation.conflictContent(
            ShadowConflictContent(shadow),
          ),
          policy: ConflictPolicy.keep,
        ).resolve(diff);
        // Built before anything is written, written after everything was.
        final lock = reconciliation.lockAfter(
          diff: diff,
          resolution: resolution,
        );

        await shadow.copyBack(
          resolution.applyTo(diff),
          approvedConflicts: resolution.approved,
        );
        await store.write(lock);
      },
    );
  }

  test(
    'removing a flavor and running everything removes its artifacts',
    () async {
      await run(_ids, flavors: ['dev', 'prod']);
      expect(fixture.project.exists('android/prod.txt'), isTrue);
      expect(fixture.project.exists('ios/prod.txt'), isTrue);

      await run(_ids, flavors: ['dev']);

      expect(fixture.project.exists('android/prod.txt'), isFalse);
      expect(fixture.project.exists('ios/prod.txt'), isFalse);
      expect(fixture.project.read('android/dev.txt'), 'android dev');
      expect((await store.read())!.flavorNames, {'dev'});
    },
  );

  test('a partial run never touches the other platform', () async {
    await run(_ids, flavors: ['dev', 'prod']);
    final iosBefore = (await store.read())!.processors['ios'];

    await run(['android'], flavors: ['dev']);

    expect(fixture.project.exists('android/prod.txt'), isFalse);
    expect(fixture.project.read('ios/prod.txt'), 'ios prod');
    final lock = (await store.read())!;
    expect(lock.processors['ios'], iosBefore);
    expect(lock.flavorNames, {'dev', 'prod'});

    // The platform that was left behind catches up on its own run.
    await run(['ios'], flavors: ['dev']);

    expect(fixture.project.exists('ios/prod.txt'), isFalse);
    expect(fixture.project.read('ios/dev.txt'), 'ios dev');
    expect((await store.read())!.processors['android']!.files.keys, [
      'android/dev.txt',
    ]);
  });

  test('a user edit survives, and its record with it', () async {
    await run(_ids, flavors: ['dev', 'prod']);
    fixture.project.write('android/prod.txt', 'mine');

    await run(_ids, flavors: ['dev']);

    expect(fixture.project.read('android/prod.txt'), 'mine');
    expect(fixture.project.exists('ios/prod.txt'), isFalse);
    expect(
      (await store.read())!.processors['android']!.files.keys,
      containsAll(['android/dev.txt', 'android/prod.txt']),
    );
  });

  test('a file tracked while a resource is torn down is not deleted', () async {
    // The lock attributes the file to `android`, which runs, but only the
    // resource tracks it, on the context of the run.
    fixture.project.write('android/extra.txt', 'extra');
    await store.write(
      FlavorizrLock(
        flavorizrVersion: '3.0.0',
        processors: {
          'android': ProcessorLock(
            files: {
              'android/extra.txt': LockedFile(
                ownership: Ownership.managed,
                hash: digestOf('extra'.codeUnits),
              ),
            },
          ),
        },
      ),
    );

    await run(
      ['android'],
      flavors: ['dev'],
      resources: [const _TeardownTracker('android/extra.txt')],
    );

    expect(fixture.project.read('android/extra.txt'), 'extra');
    expect(
      (await store.read())!.processors['android']!.files.keys,
      contains('android/extra.txt'),
    );
  });

  test('a second identical run changes nothing, not even the lock', () async {
    await run(_ids, flavors: ['dev', 'prod']);
    final first = File(
      fixture.project.abs('flavorizr.lock'),
    ).readAsStringSync();

    await run(_ids, flavors: ['dev', 'prod']);

    expect(
      File(fixture.project.abs('flavorizr.lock')).readAsStringSync(),
      first,
    );
  });
}
