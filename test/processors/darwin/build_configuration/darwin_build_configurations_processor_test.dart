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

import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:flutter_flavorizr/src/processors/darwin/build_configuration/darwin_build_configurations_processor.dart';
import 'package:flutter_flavorizr/src/processors/darwin/darwin_add_build_configuration_processor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mason_logger/mason_logger.dart';

import '../../../test_utils.dart';

void main() {
  late Flavorizr flavorizr;
  late Logger logger;

  setUp(() {
    logger = TestUtils.quietLogger();
    flavorizr = TestUtils.parseFlavorizr('test_resources/pubspec');
  });

  test(
      'Test DarwinBuildConfigurationsProcessor queues one DarwinAddBuildConfigurationProcessor per Target',
      () {
    final processor = DarwinBuildConfigurationsProcessor(
      'project.xcodeproj',
      'ios/Flutter',
      'apple',
      const {'KEY': 'VALUE'},
      config: flavorizr,
      logger: logger,
    );

    // Target enum has debug, profile, release.
    expect(processor.processors.length, 3);
    expect(processor.processors, everyElement(isA<DarwinAddBuildConfigurationProcessor>()));
  });

  test('Test DarwinBuildConfigurationsProcessor flattens ios/macos in xcconfig path', () {
    final processor = DarwinBuildConfigurationsProcessor(
      'project.xcodeproj',
      'ios/Flutter',
      'apple',
      const {},
      config: flavorizr,
      logger: logger,
    );

    final xconfigPaths = processor.processors
        .cast<DarwinAddBuildConfigurationProcessor>()
        .map((p) => p.xconfigPath)
        .toList();

    expect(xconfigPaths, contains('Flutter/appleDebug.xcconfig'));
    expect(xconfigPaths, contains('Flutter/appleProfile.xcconfig'));
    expect(xconfigPaths, contains('Flutter/appleRelease.xcconfig'));
  });

}
