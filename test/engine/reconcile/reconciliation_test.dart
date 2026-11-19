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

import 'dart:convert';

import 'package:flutter_flavorizr/src/engine/artifact.dart';
import 'package:flutter_flavorizr/src/engine/conflict/conflict_content.dart';
import 'package:flutter_flavorizr/src/engine/conflict/conflict_policy.dart';
import 'package:flutter_flavorizr/src/engine/conflict/conflict_resolver.dart';
import 'package:flutter_flavorizr/src/engine/lock/flavorizr_lock.dart';
import 'package:flutter_flavorizr/src/engine/ownership.dart';
import 'package:flutter_flavorizr/src/engine/reconcile/reconciliation.dart';
import 'package:flutter_flavorizr/src/engine/shadow/file_digest.dart';
import 'package:flutter_flavorizr/src/engine/shadow/shadow_workspace.dart';
import 'package:flutter_flavorizr/src/engine/shadow/workspace_diff.dart';
import 'package:test/test.dart';

import '../conflict/conflict_fakes.dart';
import '../shadow/shadow_fixture.dart';

String hashOf(String content) => digestOf(utf8.encode(content));

LockedFile managed(String content) =>
    LockedFile(ownership: Ownership.managed, hash: hashOf(content));

/// A project with two flavors, `dev` and `prod`, applied by an `android` and an
/// `ios` processor, and the lock that says so.
void main() {
  late ShadowFixture fixture;

  setUp(() {
    fixture = ShadowFixture();
    fixture.project.write('android/dev.xml', 'android dev');
    fixture.project.write('android/prod.xml', 'android prod');
    fixture.project.write('lib/main_prod.dart', 'main prod');
    fixture.project.write('ios/dev.xcconfig', 'ios dev');
    fixture.project.write('ios/prod.xcconfig', 'ios prod');
  });
  tearDown(() => fixture.dispose());

  final previous = FlavorizrLock(
    flavorizrVersion: '3.0.0',
    flavors: {'dev': 'f-dev', 'prod': 'f-prod'},
    processors: {
      'android': ProcessorLock(
        files: {
          'android/dev.xml': managed('android dev'),
          'android/prod.xml': managed('android prod'),
          'lib/main_prod.dart': LockedFile(ownership: Ownership.scaffold),
        },
      ),
      'ios': ProcessorLock(
        files: {
          'ios/dev.xcconfig': managed('ios dev'),
          'ios/prod.xcconfig': managed('ios prod'),
        },
      ),
    },
  );

  /// Runs the commit of a run in which only `dev` is wanted and only the
  /// processors of [ran] ran, the way the executor's commit callback would.
  Future<({Reconciliation reconciliation, FlavorizrLock lock})> commit({
    Set<String> ran = const {'android', 'ios'},
    ConflictPolicy policy = ConflictPolicy.overwrite,
    Map<String, String> desiredFlavors = const {'dev': 'f-dev'},
    Map<String, List<Artifact>>? produced,
    Map<String, String>? hashes,
    void Function(ShadowWorkspace shadow)? edit,
    FakeTerminal? terminal,
  }) async {
    final shadow = await fixture.create(['android', 'ios', 'lib']);

    edit?.call(shadow);

    final outputs =
        produced ??
        {
          if (ran.contains('android'))
            'android': [const Artifact.managed('android/dev.xml')],
          if (ran.contains('ios'))
            'ios': [const Artifact.managed('ios/dev.xcconfig')],
        };
    final reconciliation = await reconcile(
      projectRoot: fixture.project.root,
      paths: shadow.paths,
      previous: previous,
      produced: outputs,
      tracked: outputs.values.expand((artifacts) => artifacts),
      ownedHashes:
          hashes ??
          {
            'android/dev.xml': hashOf('android dev'),
            'ios/dev.xcconfig': hashOf('ios dev'),
          },
      desiredFlavors: desiredFlavors,
      availableProcessors: {'android', 'ios'},
      flavorizrVersion: '3.0.0',
    );
    final diff = reconciliation.applyTo(
      await shadow.diff(tracked: outputs.values.expand((a) => a)),
    );
    final resolution = await ConflictResolver(
      terminal: terminal ?? FakeTerminal(isInteractive: false),
      content: reconciliation.conflictContent(ShadowConflictContent(shadow)),
      policy: terminal == null ? policy : null,
    ).resolve(diff);
    // Before the copy-back: a lock that cannot be built must fail while the
    // project is still untouched.
    final lock = reconciliation.lockAfter(diff: diff, resolution: resolution);

    await shadow.copyBack(
      resolution.applyTo(diff),
      approvedConflicts: resolution.approved,
    );

    return (reconciliation: reconciliation, lock: lock);
  }

  test(
    'removing a flavor removes its artifacts and its lock entries',
    () async {
      final result = await commit();

      expect(fixture.project.exists('android/prod.xml'), isFalse);
      expect(fixture.project.exists('ios/prod.xcconfig'), isFalse);
      expect(fixture.project.exists('android/dev.xml'), isTrue);
      expect(fixture.project.exists('ios/dev.xcconfig'), isTrue);
      expect(result.lock.flavors, {'dev': 'f-dev'});
      expect(result.lock.processors['android']!.files.keys, [
        'android/dev.xml',
      ]);
      expect(result.lock.processors['ios']!.files.keys, ['ios/dev.xcconfig']);
    },
  );

  test(
    'a scaffold the lock cannot vouch for goes through the conflict flow',
    () async {
      final result = await commit();

      final change = result.reconciliation.deletions.changes.firstWhere(
        (c) => c.path == 'lib/main_prod.dart',
      );
      expect(change.disposition, ChangeDisposition.conflict);
      expect(fixture.project.exists('lib/main_prod.dart'), isFalse);
    },
  );

  test('keeping a conflict leaves the file and its record', () async {
    final result = await commit(policy: ConflictPolicy.keep);

    expect(fixture.project.read('lib/main_prod.dart'), 'main prod');
    expect(fixture.project.exists('android/prod.xml'), isFalse);
    expect(result.lock.processors['android']!.files.keys, [
      'android/dev.xml',
      'lib/main_prod.dart',
    ]);
  });

  test('a managed file edited by hand is a conflict too', () async {
    fixture.project.write('android/prod.xml', 'edited by hand');

    final kept = await commit(policy: ConflictPolicy.keep);

    expect(fixture.project.read('android/prod.xml'), 'edited by hand');
    expect(
      kept.lock.processors['android']!.files['android/prod.xml'],
      managed('android prod'),
    );
  });

  test('the diff of a deletion shows what would be lost', () async {
    final terminal = FakeTerminal(answers: ['d', 'k']);

    await commit(terminal: terminal);

    expect(terminal.output.toString(), contains('main prod'));
    expect(
      terminal.output.toString(),
      isNot(contains('No textual differences')),
    );
    expect(fixture.project.read('lib/main_prod.dart'), 'main prod');
  });

  test('a stale file a processor removed by itself keeps its record', () async {
    // The processor deleted it in the workspace without tracking it: copy-back
    // never writes that, so the file stays and the lock must still know it.
    final result = await commit(
      edit: (shadow) => shadow.delete('ios/prod.xcconfig'),
    );

    expect(fixture.project.read('ios/prod.xcconfig'), 'ios prod');
    expect(
      result.lock.processors['ios']!.files.keys,
      contains('ios/prod.xcconfig'),
    );
  });

  test('a partial run never touches the other platforms', () async {
    final result = await commit(ran: {'android'});

    expect(fixture.project.exists('android/prod.xml'), isFalse);
    expect(fixture.project.read('ios/prod.xcconfig'), 'ios prod');
    expect(fixture.project.read('ios/dev.xcconfig'), 'ios dev');
    expect(result.lock.processors['ios'], previous.processors['ios']);
    expect(result.lock.flavors, previous.flavors);
  });

  test('the plan names what a removed flavor takes away', () async {
    final result = await commit();

    expect(
      result.reconciliation.render(),
      '- prod (removed)\n'
      '\n'
      'Files to delete:\n'
      '- android/prod.xml (managed)\n'
      '- ios/prod.xcconfig (managed)\n'
      '- lib/main_prod.dart (scaffold) [conflict]',
    );
  });

  test(
    'a rename is applied as a removal plus an addition, and says so',
    () async {
      fixture.project.write('android/stage.xml', 'android stage');
      final renamed = FlavorizrLock(
        flavorizrVersion: '3.0.0',
        flavors: {'stage': 'f-1'},
        processors: {
          'android': ProcessorLock(
            files: {'android/stage.xml': managed('android stage')},
          ),
        },
      );
      final shadow = await fixture.create(['android']);

      final reconciliation = await reconcile(
        projectRoot: fixture.project.root,
        paths: shadow.paths,
        previous: renamed,
        produced: {
          'android': [const Artifact.managed('android/staging.xml')],
        },
        tracked: [const Artifact.managed('android/staging.xml')],
        ownedHashes: {'android/staging.xml': 'h'},
        desiredFlavors: {'staging': 'f-1'},
        availableProcessors: {'android'},
        flavorizrVersion: '3.0.0',
      );

      expect(
        reconciliation.render(),
        '- stage (removed)\n'
        '+ staging (added)\n'
        'stage -> staging is a rename: it is applied as the removal of `stage` '
        'plus the addition of `staging`.\n'
        '\n'
        'Files to delete:\n'
        '- android/stage.xml (managed)',
      );
    },
  );

  test(
    'a patched file the processor stopped producing is left in place',
    () async {
      final shadow = await fixture.create(['android']);
      final reconciliation = await reconcile(
        projectRoot: fixture.project.root,
        paths: shadow.paths,
        previous: FlavorizrLock(
          flavorizrVersion: '3.0.0',
          processors: {
            'android': ProcessorLock(
              files: {
                'android/dev.xml': LockedFile(
                  ownership: Ownership.patched,
                  hash: 'h',
                ),
              },
            ),
          },
        ),
        produced: {'android': const []},
        tracked: const [],
        ownedHashes: const {},
        desiredFlavors: const {},
        availableProcessors: {'android'},
        flavorizrVersion: '3.0.0',
      );

      expect(reconciliation.deletions.changes, isEmpty);
      expect(
        reconciliation.render(),
        endsWith(
          'Left in place (shared with you, no longer owned by flavorizr):\n'
          '- android/dev.xml',
        ),
      );
      expect(
        reconciliation
            .lockAfter(
              diff: reconciliation.applyTo(await shadow.diff()),
              resolution: ConflictResolution(approved: [], kept: []),
            )
            .processors,
        isEmpty,
      );
    },
  );
}
