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

import 'package:flutter_flavorizr/src/engine/execution_plan.dart';
import 'package:flutter_flavorizr/src/engine/plan_executor.dart';
import 'package:flutter_flavorizr/src/engine/processors/android/android_icons_processor.dart';
import 'package:flutter_flavorizr/src/engine/shadow/file_digest.dart';
import 'package:flutter_flavorizr/src/engine/shadow/workspace_diff.dart';
import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../../test_utils.dart';
import 'android_icon_source_test.dart' show gradientPng;

const _defaultConfig = '''
flavors:
  apple:
    app:
      name: "Apple"
      icon: "assets/apple.png"
    android:
      applicationId: "com.example.apple"
''';

/// Runs the icons through the executor and the shadow workspace like the CLI
/// will, and covers what the engine does with binary managed artifacts.
void main() {
  late Directory project;
  late Map<String, String> recorded;
  late String config;

  File file(String path) => File(p.join(project.path, path));

  Future<WorkspaceDiff> run() async {
    late WorkspaceDiff diff;
    const processors = [AndroidIconsProcessor()];

    final report = await PlanExecutor(logger: TestUtils.quietLogger()).execute(
      resolveExecutionPlan(processors, requested: ['android:icons']),
      config: Flavorizr.parse(config),
      projectRoot: project,
      // The icons are written below `src`: the caller whitelists it.
      paths: ['android/app/src'],
      commit: (shadow, ctx) async {
        diff = await shadow.diff(
          tracked: ctx.tracked,
          recordedHashes: recorded,
          hasher: (artifact, bytes) => digestOf(bytes),
        );
        if (diff.hasConflicts) return;

        await shadow.copyBack(diff);
        recorded = {
          for (final artifact in ctx.tracked)
            artifact.path: digestOf(file(artifact.path).readAsBytesSync()),
        };
      },
    );

    expect(report.succeeded, isTrue, reason: report.render());

    return diff;
  }

  setUp(() {
    final temp = Directory.systemTemp.createTempSync('flavorizr_icons_run_');
    addTearDown(() => temp.deleteSync(recursive: true));

    project = Directory(p.join(temp.path, 'project'))..createSync();
    recorded = {};
    config = _defaultConfig;
    file('assets/apple.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(gradientPng(256, 256));
  });

  test(
    'the first run adds the icons of the flavor, as managed files',
    () async {
      final diff = await run();

      expect(diff.changes.map((change) => change.describe()), [
        for (final folder in [
          'mipmap-hdpi',
          'mipmap-mdpi',
          'mipmap-xhdpi',
          'mipmap-xxhdpi',
          'mipmap-xxxhdpi',
        ])
          '+ android/app/src/apple/res/$folder/ic_launcher.png (managed)',
      ]);
      expect(
        file(
          'android/app/src/apple/res/mipmap-mdpi/ic_launcher.png',
        ).existsSync(),
        isTrue,
      );
    },
  );

  test('an idempotent re-run produces an empty diff', () async {
    await run();

    final diff = await run();

    expect(diff.isEmpty, isTrue, reason: diff.render());
  });

  test(
    'an idempotent re-run with adaptive icons produces an empty diff',
    () async {
      file('assets/fg.png').writeAsBytesSync(gradientPng(120, 120));
      file('assets/mono.png').writeAsBytesSync(gradientPng(60, 60));
      config = '''
flavors:
  apple:
    app:
      name: "Apple"
      icon: "assets/apple.png"
    android:
      applicationId: "com.example.apple"
      adaptiveIcon:
        foreground: "assets/fg.png"
        background: "assets/apple.png"
        monochrome: "assets/mono.png"
  banana:
    app:
      name: "Banana"
      icon: "assets/apple.png"
    android:
      applicationId: "com.example.banana"
''';

      final first = await run();
      final second = await run();

      expect(first.changes, hasLength(5 + 16 + 5));
      expect(second.isEmpty, isTrue, reason: second.render());
    },
  );

  test('a new source icon rewrites the icons, and only them', () async {
    await run();
    file('assets/apple.png').writeAsBytesSync(gradientPng(300, 200));

    final diff = await run();

    expect(diff.changes, hasLength(5));
    expect(
      diff.changes.map((change) => change.describe()),
      everyElement(startsWith('~ android/app/src/apple/res/mipmap-')),
    );
  });

  test('a hand edit of a generated icon is a conflict', () async {
    await run();
    file(
      'android/app/src/apple/res/mipmap-hdpi/ic_launcher.png',
    ).writeAsBytesSync([1, 2, 3]);
    file('assets/apple.png').writeAsBytesSync(gradientPng(300, 200));

    final diff = await run();

    expect(diff.conflicts.map((change) => change.path), [
      'android/app/src/apple/res/mipmap-hdpi/ic_launcher.png',
    ]);
  });
}
