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

import 'package:dart_xcodeproj/dart_xcodeproj.dart';
import 'package:flutter_flavorizr/src/engine/execution_plan.dart';
import 'package:flutter_flavorizr/src/engine/plan_executor.dart';
import 'package:flutter_flavorizr/src/engine/resources/xcodeproj_resource.dart';
import 'package:flutter_flavorizr/src/engine/shadow/file_digest.dart';
import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:flutter_flavorizr/src/processors/darwin/darwin_add_file_processor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../test_utils.dart';
import 'xcodeproj_fixture.dart';

const _pbxproj = 'ios/Runner.xcodeproj/project.pbxproj';

/// The 2.x processors open and save the project each, the engine once for all
/// of them: the project they leave must be the same, byte for byte.
void main() {
  late Directory legacy;
  late Directory engine;

  final config = Flavorizr.parse(
    'flavors:\n  apple:\n    app:\n      name: apple\n'
    '    ios:\n      bundleId: com.example.apple\n',
  );

  setUp(() {
    final temp = Directory.systemTemp.createTempSync('flavorizr_parity_');
    addTearDown(() => temp.deleteSync(recursive: true));

    for (final directory in [
      legacy = Directory(p.join(temp.path, 'legacy')),
      engine = Directory(p.join(temp.path, 'engine')),
    ]) {
      final file = File(p.join(directory.path, _pbxproj))
        ..createSync(recursive: true);

      File('example/$_pbxproj').copySync(file.path);
    }
  });

  test(
    'adding files through the shared project writes what 2.x wrote',
    () async {
      const files = ['oneDebug.xcconfig', 'oneRelease.xcconfig', 'logo.png'];

      for (final path in files) {
        await DarwinAddFileProcessor(
          p.join(legacy.path, XcodeprojResource.iosProject),
          path,
          config: config,
          logger: TestUtils.quietLogger(),
        ).execute();
      }

      final processors = [
        for (final (index, path) in files.indexed)
          XcodeprojTestProcessor(
            'test:add$index',
            XcodeprojResource.iosKey,
            XcodeprojResource.iosArtifact,
            (project) => DarwinAddFileProcessor.addTo(project, path),
            after: {if (index > 0) 'test:add${index - 1}'},
          ),
      ];
      var saves = 0;
      final report = await PlanExecutor(logger: TestUtils.quietLogger())
          .execute(
            resolveExecutionPlan(
              processors,
              requested: processors.map((p) => p.id),
            ),
            config: config,
            projectRoot: engine,
            paths: [XcodeprojResource.iosProject],
            resources: [
              XcodeprojResource.ios(
                save: (project) {
                  saves++;

                  return project.save();
                },
              ),
            ],
            commit: (shadow, ctx) async => shadow.copyBack(
              await shadow.diff(
                tracked: ctx.tracked,
                recordedHashes: const {},
                hasher: (_, bytes) => digestOf(bytes),
              ),
            ),
          );

      expect(report.succeeded, isTrue, reason: report.render());
      expect(saves, 1);
      // The UUIDs of the objects they create are random, in 2.x as here: what
      // must match is the project, which the differ compares by content.
      final legacyProject = await XcodeProject.open(
        p.join(legacy.path, XcodeprojResource.iosProject),
      );
      final engineProject = await XcodeProject.open(
        p.join(engine.path, XcodeprojResource.iosProject),
      );

      expect(Differ.projectDiff(legacyProject, engineProject), isNull);
      expect(
        File(p.join(engine.path, _pbxproj)).readAsLinesSync(),
        hasLength(File(p.join(legacy.path, _pbxproj)).readAsLinesSync().length),
      );
    },
  );
}
