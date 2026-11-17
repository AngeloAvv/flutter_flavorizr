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
import 'dart:io';

import 'package:flutter_flavorizr/src/engine/artifact.dart';
import 'package:flutter_flavorizr/src/engine/conflict/conflict_content.dart';
import 'package:flutter_flavorizr/src/engine/conflict/conflict_policy.dart';
import 'package:flutter_flavorizr/src/engine/conflict/conflict_resolver.dart';
import 'package:flutter_flavorizr/src/engine/execution_plan.dart';
import 'package:flutter_flavorizr/src/engine/lock/flavorizr_lock.dart';
import 'package:flutter_flavorizr/src/engine/lock/lock_store.dart';
import 'package:flutter_flavorizr/src/engine/ownership.dart';
import 'package:flutter_flavorizr/src/engine/plan_executor.dart';
import 'package:flutter_flavorizr/src/engine/processors/android/android_build_gradle_editor.dart';
import 'package:flutter_flavorizr/src/engine/processors/android/android_build_gradle_patch_processor.dart';
import 'package:flutter_flavorizr/src/engine/processors/android/android_icons_processor.dart';
import 'package:flutter_flavorizr/src/engine/processors/android/android_manifest_editor.dart';
import 'package:flutter_flavorizr/src/engine/processors/android/android_manifest_patch_processor.dart';
import 'package:flutter_flavorizr/src/engine/processors/android/flavorizr_gradle_processor.dart';
import 'package:flutter_flavorizr/src/engine/reconcile/reconciliation.dart';
import 'package:flutter_flavorizr/src/engine/shadow/file_digest.dart';
import 'package:flutter_flavorizr/src/engine/shadow/workspace_diff.dart';
import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../../test_utils.dart';
import '../../conflict/conflict_fakes.dart';
import 'android_icon_source_test.dart' show gradientPng;

const _manifestPath = 'android/app/src/main/AndroidManifest.xml';
const _manifest = '''
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- the application -->
    <application
        android:label="example"
        android:name="\${applicationName}">
        <meta-data android:name="flutterEmbedding" android:value="2" />
    </application>
</manifest>
''';

const _build = '''
plugins {
    id "com.android.application"
}

android {
    namespace "com.example.app"
}
''';

/// The processors of the `android:*` group that exist in the engine.
const _processors = [
  FlavorizrGradleProcessor(),
  AndroidBuildGradlePatchProcessor(),
  AndroidManifestPatchProcessor(),
  AndroidIconsProcessor(),
];

String _flavor(String name, {bool icon = true}) =>
    '''
  $name:
    app:
      name: "$name app"
${icon ? '      icon: "assets/icon.png"\n' : ''}    android:
      applicationId: "com.example.$name"
''';

String _config(Map<String, bool> flavors) =>
    'flavors:\n${[for (final MapEntry(:key, :value) in flavors.entries) _flavor(key, icon: value)].join()}';

String _hash(Artifact artifact, List<int> bytes) {
  if (artifact.ownership != Ownership.patched) return digestOf(bytes);

  final text = utf8.decode(bytes);

  return digestOf(
    utf8.encode(
      artifact.path == _manifestPath
          ? AndroidManifestEditor.ownedContent(text)
          : AndroidBuildGradleEditor.ownedContent(text),
    ),
  );
}

/// What a run did, and the project the way it left it.
class _Run {
  final WorkspaceDiff diff;
  final Reconciliation reconciliation;

  _Run(this.diff, this.reconciliation);
}

/// Runs the Android processors on a project the way the CLI will: the executor,
/// then the reconciliation of stale files, the conflict resolution, the
/// copy-back and finally the lock.
void main() {
  late Directory project;
  late LockStore store;

  File file(String path) => File(p.join(project.path, path));

  bool exists(String path) =>
      FileSystemEntity.typeSync(p.join(project.path, path)) !=
      FileSystemEntityType.notFound;

  Future<_Run> run(
    Map<String, bool> flavors, {
    ConflictPolicy policy = ConflictPolicy.keep,
  }) async {
    late _Run result;

    final report = await PlanExecutor(logger: TestUtils.quietLogger()).execute(
      resolveExecutionPlan(
        _processors,
        requested: _processors.map((processor) => processor.id),
      ),
      config: Flavorizr.parse(_config(flavors)),
      projectRoot: project,
      paths: [
        'android/app/flavorizr.gradle',
        'android/app/flavorizr.gradle.kts',
        'android/app/build.gradle',
        'android/app/build.gradle.kts',
        'android/app/src',
      ],
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
              artifact.path: _hash(
                artifact,
                File(ctx.resolve(artifact.path)).readAsBytesSync(),
              ),
          },
          desiredFlavors: {
            for (final flavor in flavors.keys)
              flavor: digestOf(
                utf8.encode(_flavor(flavor, icon: flavors[flavor]!)),
              ),
          },
          availableProcessors: {for (final p in _processors) p.id},
          flavorizrVersion: '3.0.0',
          hasher: _hash,
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
            hasher: _hash,
          ),
        );
        final resolution = await ConflictResolver(
          terminal: FakeTerminal(isInteractive: false),
          content: reconciliation.conflictContent(
            ShadowConflictContent(shadow),
          ),
          policy: policy,
        ).resolve(diff);
        final lock = reconciliation.lockAfter(
          diff: diff,
          resolution: resolution,
        );

        await shadow.copyBack(
          resolution.applyTo(diff),
          approvedConflicts: resolution.approved,
        );
        await store.write(lock);
        result = _Run(diff, reconciliation);
      },
    );

    expect(report.succeeded, isTrue, reason: report.render());

    return result;
  }

  setUp(() {
    final temp = Directory.systemTemp.createTempSync('flavorizr_removal_');
    addTearDown(() => temp.deleteSync(recursive: true));

    project = Directory(p.join(temp.path, 'project'))..createSync();
    store = LockStore(project, runningVersion: '3.0.0');
    file(_manifestPath)
      ..createSync(recursive: true)
      ..writeAsStringSync(_manifest);
    file('assets/icon.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(gradientPng(256, 256));
  });

  for (final (gradle, dsl) in [
    ('gradle', 'Groovy'),
    ('gradle.kts', 'Kotlin'),
  ]) {
    group('Removing a flavor from a $dsl project', () {
      const apple = 'android/app/src/apple/res';
      const banana = 'android/app/src/banana/res';

      setUp(() {
        file('android/app/build.$gradle')
          ..createSync(recursive: true)
          ..writeAsStringSync(_build);
      });

      test(
        'drops its product flavor and its res directory, and nothing else',
        () async {
          await run({'apple': true, 'banana': true});
          expect(exists('$banana/mipmap-mdpi/ic_launcher.png'), isTrue);
          final buildBefore = file(
            'android/app/build.$gradle',
          ).readAsStringSync();
          final manifestBefore = file(_manifestPath).readAsStringSync();
          final appleIcons = file(
            '$apple/mipmap-hdpi/ic_launcher.png',
          ).readAsBytesSync();

          final removal = await run({'apple': true});

          expect(
            file('android/app/flavorizr.$gradle').readAsStringSync(),
            allOf(contains('apple'), isNot(contains('banana'))),
          );
          expect(exists('android/app/src/banana'), isFalse);
          expect(
            file('$apple/mipmap-hdpi/ic_launcher.png').readAsBytesSync(),
            appleIcons,
          );
          expect(
            file('android/app/build.$gradle').readAsStringSync(),
            buildBefore,
          );
          expect(file(_manifestPath).readAsStringSync(), manifestBefore);
          expect(removal.diff.changes.map((change) => change.describe()), [
            '~ android/app/flavorizr.$gradle (managed)',
            for (final density in [
              'hdpi',
              'mdpi',
              'xhdpi',
              'xxhdpi',
              'xxxhdpi',
            ])
              '- android/app/src/banana/res/mipmap-$density/ic_launcher.png (managed)',
          ]);
          expect((await store.read())!.flavorNames, {'apple'});
          expect(
            (await store.read())!.processors['android:icons']!.files.keys,
            everyElement(startsWith('android/app/src/apple/')),
          );
        },
      );

      test(
        'an idempotent re-run after the removal produces an empty diff',
        () async {
          await run({'apple': true, 'banana': true});
          await run({'apple': true});

          final diff = (await run({'apple': true})).diff;

          expect(diff.isEmpty, isTrue, reason: diff.render());
        },
      );

      test('removing the icon of a flavor removes its res directory but keeps '
          'the flavor', () async {
        await run({'apple': true, 'banana': true});

        await run({'apple': true, 'banana': false});

        expect(exists('android/app/src/banana'), isFalse);
        expect(
          file('android/app/flavorizr.$gradle').readAsStringSync(),
          contains('banana'),
        );
        expect((await store.read())!.flavorNames, {'apple', 'banana'});
      });

      test('a file of the user in the res directory stays, and so does its '
          'folder', () async {
        await run({'apple': true, 'banana': true});
        file('$banana/values/strings.xml')
          ..createSync(recursive: true)
          ..writeAsStringSync('<resources/>');

        await run({'apple': true});

        expect(
          file('$banana/values/strings.xml').readAsStringSync(),
          '<resources/>',
        );
        expect(exists('$banana/mipmap-mdpi'), isFalse);
        expect(exists('$banana/mipmap-hdpi/ic_launcher.png'), isFalse);
        expect((await run({'apple': true})).diff.isEmpty, isTrue);
      });

      test('an icon the user edited by hand is left in place, and still '
          'recorded', () async {
        await run({'apple': true, 'banana': true});
        const edited = '$banana/mipmap-hdpi/ic_launcher.png';
        file(edited).writeAsBytesSync([1, 2, 3]);

        final removal = await run({'apple': true});

        expect(removal.diff.conflicts.map((change) => change.path), [edited]);
        expect(file(edited).readAsBytesSync(), [1, 2, 3]);
        expect(exists('$banana/mipmap-mdpi'), isFalse);
        expect(
          (await store.read())!.processors['android:icons']!.files.keys,
          contains(edited),
        );
      });

      test(
        'the manifest outside the label is no business of a removal',
        () async {
          await run({'apple': true, 'banana': true});
          final edited = file(_manifestPath).readAsStringSync().replaceFirst(
            '<!-- the application -->',
            '<uses-permission android:name="x" /><!-- edited -->',
          );
          file(_manifestPath).writeAsStringSync(edited);

          final removal = await run({'apple': true});

          expect(file(_manifestPath).readAsStringSync(), edited);
          expect(
            removal.diff.changes.map((change) => change.path),
            isNot(contains(_manifestPath)),
          );
        },
      );
    });
  }
}
