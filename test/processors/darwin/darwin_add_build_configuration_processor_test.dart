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

import 'package:dart_xcodeproj/dart_xcodeproj.dart';
import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:flutter_flavorizr/src/processors/darwin/darwin_add_build_configuration_processor.dart';
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
      'Test DarwinAddBuildConfigurationProcessor adds a new target and project build configuration',
      () async {
    await TestUtils.withTempDir((dir) async {
      final projectPath = '${dir.path}/Runner.xcodeproj';
      copyPathSync(exampleProjectPath, projectPath);

      final processor = DarwinAddBuildConfigurationProcessor(
        projectPath,
        'Flutter/appleDebug.xcconfig',
        'orange',
        'Debug',
        const {'PRODUCT_BUNDLE_IDENTIFIER': 'com.example.orange'},
        config: flavorizr,
        logger: logger,
      );

      await processor.execute();

      final reopened = await XcodeProject.open(projectPath);
      final target = reopened.targets.first;

      expect(
        target.buildConfigurationList!.buildConfigurations
            .any((c) => c.name == 'Debug-orange'),
        isTrue,
      );
      expect(
        reopened.buildConfigurations.any((c) => c.name == 'Debug-orange'),
        isTrue,
      );
    });
  });

  test(
      'Test DarwinAddBuildConfigurationProcessor throws when the xcconfig file reference does not exist',
      () async {
    await TestUtils.withTempDir((dir) async {
      final projectPath = '${dir.path}/Runner.xcodeproj';
      copyPathSync(exampleProjectPath, projectPath);

      final processor = DarwinAddBuildConfigurationProcessor(
        projectPath,
        'nonExistentFileReference.xcconfig',
        'orange',
        'Debug',
        const {},
        config: flavorizr,
        logger: logger,
      );

      await expectLater(processor.execute(), throwsStateError);
    });
  });

}
