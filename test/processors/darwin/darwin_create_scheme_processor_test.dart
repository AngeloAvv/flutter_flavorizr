/*
 * Copyright (c) 2024 Angelo Cassano
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
import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:flutter_flavorizr/src/processors/darwin/darwin_create_scheme_processor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:io/io.dart';
import 'package:mason_logger/mason_logger.dart';

import '../../test_utils.dart';

void main() {
  late Flavorizr flavorizr;
  late Logger logger;

  const exampleProjectPath = 'example/ios/Runner.xcodeproj';

  setUp(() {
    logger = TestUtils.quietLogger();
    flavorizr = TestUtils.parseFlavorizr('test_resources/pubspec');
  });

  test(
    'Test DarwinCreateSchemeProcessor writes an xcscheme file with the flavor build configurations',
    () async {
      await TestUtils.withTempDir((dir) async {
        final projectPath = '${dir.path}/Runner.xcodeproj';
        copyPathSync(exampleProjectPath, projectPath);

        final processor = DarwinCreateSchemeProcessor(
          projectPath,
          'orange',
          config: flavorizr,
          logger: logger,
        );

        await processor.execute();

        final schemeFile = File(
          '$projectPath/xcshareddata/xcschemes/orange.xcscheme',
        );
        expect(schemeFile.existsSync(), isTrue);

        final content = schemeFile.readAsStringSync();
        expect(content, contains('Debug-orange'));
        expect(content, contains('Release-orange'));
        expect(content, contains('Profile-orange'));

        final launchActionMatch = RegExp(
          r'<LaunchAction[\s\S]*?</LaunchAction>',
        ).firstMatch(content);
        expect(launchActionMatch, isNotNull);
        expect(
          launchActionMatch!.group(0),
          contains('BuildableProductRunnable'),
        );

        final profileActionMatch = RegExp(
          r'<ProfileAction[\s\S]*?</ProfileAction>',
        ).firstMatch(content);
        expect(profileActionMatch, isNotNull);
        final profileActionContent = profileActionMatch!.group(0)!;
        expect(profileActionContent, contains('BuildableProductRunnable'));
        expect(profileActionContent, contains('BuildableName = "Runner.app"'));
        expect(profileActionContent, contains('BlueprintName = "Runner"'));
        expect(
          profileActionContent,
          contains('ReferencedContainer = "container:Runner.xcodeproj"'),
        );

        final testActionMatch = RegExp(
          r'<TestAction[\s\S]*?</TestAction>',
        ).firstMatch(content);
        expect(testActionMatch, isNotNull);
        final testActionContent = testActionMatch!.group(0)!;
        expect(testActionContent, contains('MacroExpansion'));
        expect(testActionContent, contains('BuildableName = "Runner.app"'));
        expect(testActionContent, contains('BlueprintName = "Runner"'));
        expect(
          testActionContent,
          contains('ReferencedContainer = "container:Runner.xcodeproj"'),
        );
        expect(testActionContent, contains('<Testables>'));
        expect(
          testActionContent,
          contains('BuildableName = "RunnerTests.xctest"'),
        );
        expect(testActionContent, contains('BlueprintName = "RunnerTests"'));
      });
    },
  );

  test(
    'Test DarwinCreateSchemeProcessor does not duplicate testables when run twice',
    () async {
      await TestUtils.withTempDir((dir) async {
        final projectPath = '${dir.path}/Runner.xcodeproj';
        copyPathSync(exampleProjectPath, projectPath);

        final processor = DarwinCreateSchemeProcessor(
          projectPath,
          'orange',
          config: flavorizr,
          logger: logger,
        );

        await processor.execute();
        await processor.execute();

        final content = File(
          '$projectPath/xcshareddata/xcschemes/orange.xcscheme',
        ).readAsStringSync();

        expect(
          'BuildableName = "RunnerTests.xctest"'.allMatches(content).length,
          1,
        );
      });
    },
  );

  test(
    'Test DarwinCreateSchemeProcessor generates testables for unit-test and ui-testing targets',
    () async {
      await TestUtils.withTempDir((dir) async {
        final projectPath = '${dir.path}/Runner.xcodeproj';
        copyPathSync(exampleProjectPath, projectPath);

        // The example project ships a unit-test target (RunnerTests); add a
        // ui-testing target so both product types are exercised.
        final project = await XcodeProject.open(projectPath);
        final uiTestTarget =
            project.newObject<PBXNativeTarget>((g, u) => PBXNativeTarget(g, u))
              ..name = 'RunnerUITests'
              ..productName = 'RunnerUITests'
              ..productType = 'com.apple.product-type.bundle.ui-testing';
        project.targets.add(uiTestTarget);
        await project.save();

        final processor = DarwinCreateSchemeProcessor(
          projectPath,
          'orange',
          config: flavorizr,
          logger: logger,
        );

        await processor.execute();

        final content = File(
          '$projectPath/xcshareddata/xcschemes/orange.xcscheme',
        ).readAsStringSync();

        expect(content, contains('BuildableName = "RunnerTests.xctest"'));
        expect(content, contains('BuildableName = "RunnerUITests.xctest"'));
      });
    },
  );
}
