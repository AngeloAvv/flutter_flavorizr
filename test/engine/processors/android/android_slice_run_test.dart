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
import 'package:flutter_flavorizr/src/engine/execution_plan.dart';
import 'package:flutter_flavorizr/src/engine/ownership.dart';
import 'package:flutter_flavorizr/src/engine/plan_executor.dart';
import 'package:flutter_flavorizr/src/engine/processors/android/android_manifest_editor.dart';
import 'package:flutter_flavorizr/src/engine/processors/android/android_manifest_patch_processor.dart';
import 'package:flutter_flavorizr/src/engine/processors/android/flavorizr_gradle_processor.dart';
import 'package:flutter_flavorizr/src/engine/shadow/file_digest.dart';
import 'package:flutter_flavorizr/src/engine/shadow/workspace_diff.dart';
import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../../test_utils.dart';

const _manifestPath = 'android/app/src/main/AndroidManifest.xml';

const _manifest = '''
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- the application -->
    <application
        android:label="example"
        android:name="\${applicationName}"
        android:icon="@mipmap/ic_launcher">
        <meta-data android:name="flutterEmbedding" android:value="2" />
    </application>
</manifest>
''';

String _config(Iterable<String> flavors) =>
    'flavors:\n${[for (final flavor in flavors) '''
  $flavor:
    app:
      name: "$flavor app"
    android:
      applicationId: "com.example.$flavor"
''']
        .join()}';

/// Hashes the owned content of an artifact, like the lock does: the whole file
/// for a managed one, the label for the manifest.
String _hash(Artifact artifact, List<int> bytes) =>
    artifact.ownership == Ownership.patched
    ? digestOf(utf8.encode(AndroidManifestEditor.ownedContent(utf8.decode(bytes))))
    : digestOf(bytes);

void main() {
  late Directory project;
  late Map<String, String> recorded;

  File file(String path) => File(p.join(project.path, path));

  /// Runs both processors on the project, commits like the CLI will do and
  /// returns the diff the run produced.
  Future<WorkspaceDiff> run(Iterable<String> flavors, String gradle) async {
    late WorkspaceDiff diff;
    final processors = [
      const FlavorizrGradleProcessor(),
      const AndroidManifestPatchProcessor(),
    ];

    final report = await PlanExecutor(logger: TestUtils.quietLogger()).execute(
      resolveExecutionPlan(processors, requested: processors.map((p) => p.id)),
      config: Flavorizr.parse(_config(flavors)),
      projectRoot: project,
      paths: [
        'android/app/build.gradle',
        'android/app/build.gradle.kts',
        'android/app/flavorizr.gradle',
        'android/app/flavorizr.gradle.kts',
        _manifestPath,
      ],
      commit: (shadow, ctx) async {
        diff = await shadow.diff(
          tracked: ctx.tracked,
          recordedHashes: recorded,
          hasher: _hash,
        );
        if (diff.hasConflicts) return;

        await shadow.copyBack(diff);
        recorded = {
          for (final artifact in ctx.tracked)
            artifact.path: _hash(
              artifact,
              file(artifact.path).readAsBytesSync(),
            ),
        };
      },
    );

    expect(report.succeeded, isTrue, reason: report.render());

    return diff;
  }

  setUp(() {
    final temp = Directory.systemTemp.createTempSync('flavorizr_android_run_');
    addTearDown(() => temp.deleteSync(recursive: true));

    project = Directory(p.join(temp.path, 'project'))..createSync();
    recorded = {};
    file(_manifestPath)
      ..createSync(recursive: true)
      ..writeAsStringSync(_manifest);
  });

  for (final (gradle, dsl) in [
    ('gradle', 'Groovy'),
    ('gradle.kts', 'Kotlin'),
  ]) {
    group('The android slice on a $dsl project', () {
      setUp(() {
        file('android/app/build.$gradle')
          ..createSync(recursive: true)
          ..writeAsStringSync('// the build file of the user\n');
      });

      test('writes the flavors file and relabels the application, nothing else', () async {
        final diff = await run(['apple', 'banana'], gradle);

        expect(diff.changes.map((change) => change.describe()), [
          '+ android/app/flavorizr.$gradle (managed)',
          '~ $_manifestPath (patched)',
        ]);
        expect(
          file('android/app/flavorizr.$gradle').readAsStringSync(),
          allOf(contains('apple'), contains('banana')),
        );
        expect(
          file(_manifestPath).readAsStringSync(),
          _manifest.replaceFirst('"example"', '"@string/app_name"'),
        );
        expect(
          file('android/app/build.$gradle').readAsStringSync(),
          '// the build file of the user\n',
        );
      });

      test('an idempotent re-run produces an empty diff', () async {
        await run(['apple', 'banana'], gradle);

        final diff = await run(['apple', 'banana'], gradle);

        expect(diff.isEmpty, isTrue, reason: diff.render());
      });

      test('removing a flavor and rebuilding drops it from the flavors and '
          'changes nothing else', () async {
        await run(['apple', 'banana'], gradle);

        final diff = await run(['apple'], gradle);

        expect(diff.changes.map((change) => change.describe()), [
          '~ android/app/flavorizr.$gradle (managed)',
        ]);
        expect(
          file('android/app/flavorizr.$gradle').readAsStringSync(),
          allOf(contains('apple'), isNot(contains('banana'))),
        );
        expect(
          file(_manifestPath).readAsStringSync(),
          _manifest.replaceFirst('"example"', '"@string/app_name"'),
        );

        expect((await run(['apple'], gradle)).isEmpty, isTrue);
      });

      test('a hand edit of the manifest outside the label is no drift and '
          'survives the next run', () async {
        await run(['apple'], gradle);
        final edited = file(_manifestPath).readAsStringSync().replaceFirst(
          '<!-- the application -->',
          '<uses-permission android:name="x" /><!-- edited -->',
        );
        file(_manifestPath).writeAsStringSync(edited);

        final diff = await run(['apple'], gradle);

        expect(diff.isEmpty, isTrue, reason: diff.render());
        expect(file(_manifestPath).readAsStringSync(), edited);
      });

      test('a hand edit of the label is a conflict', () async {
        await run(['apple'], gradle);
        file(_manifestPath).writeAsStringSync(
          file(_manifestPath).readAsStringSync().replaceFirst(
            '@string/app_name',
            'my own label',
          ),
        );

        final diff = await run(['apple'], gradle);

        expect(diff.conflicts.map((change) => change.path), [_manifestPath]);
      });

      test('a hand edit of the flavors file is a conflict', () async {
        await run(['apple'], gradle);
        file('android/app/flavorizr.$gradle').writeAsStringSync('// mine');

        final diff = await run(['apple', 'banana'], gradle);

        expect(diff.conflicts.map((change) => change.path), [
          'android/app/flavorizr.$gradle',
        ]);
      });
    });
  }
}
