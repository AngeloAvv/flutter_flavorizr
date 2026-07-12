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

import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:flutter_flavorizr/src/processors/darwin/build_configuration/darwin_build_configurations_processor.dart';
import 'package:flutter_flavorizr/src/processors/ios/build_configuration/ios_build_configurations_targets_processor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

import '../../../test_utils.dart';

void main() {
  late Flavorizr flavorizr;
  late Logger logger;

  setUp(() {
    logger = TestUtils.quietLogger();
    flavorizr = TestUtils.parseFlavorizr(
      'test_resources/ios/build_configuration_targets_processor_test/pubspec',
    );
  });

  test(
      'IOSBuildConfigurationsTargetsProcessor wires one DarwinBuildConfigurationsProcessor per iOS flavor',
      () {
    final processor = IOSBuildConfigurationsTargetsProcessor(
      'project',
      'file',
      config: flavorizr,
      logger: logger,
    );

    expect(processor.processors.length, flavorizr.iosFlavors.length);
    expect(
      processor.processors,
      everyElement(isA<DarwinBuildConfigurationsProcessor>()),
    );
  });

  test(
      'IOSBuildConfigurationsTargetsProcessor.execute adds a build configuration per flavor/target to a real Xcode project',
      () {
    TestUtils.withTempDir((dir) async {
      final projectSourceDir = Directory(
          'test_resources/ios/build_configuration_targets_processor_test/Runner.xcodeproj');
      final projectDestDir =
          Directory(p.join(dir.path, 'Runner.xcodeproj'))..createSync();

      for (final entity in projectSourceDir.listSync()) {
        if (entity is File) {
          entity.copySync(p.join(projectDestDir.path,
              p.basename(entity.path)));
        }
      }

      // The fixture project already declares file references for
      // `Flutter/<flavor><Mode>.xcconfig` (e.g. Flutter/appleDebug.xcconfig),
      // so passing `Flutter` as the containing folder makes
      // DarwinAddBuildConfigurationProcessor resolve an existing
      // PBXFileReference via utils.flatPath.
      final processor = IOSBuildConfigurationsTargetsProcessor(
        projectDestDir.path,
        'Flutter',
        config: flavorizr,
        logger: logger,
      );

      await processor.execute();

      final pbxprojContent =
          File(p.join(projectDestDir.path, 'project.pbxproj'))
              .readAsStringSync();

      for (final flavorName in flavorizr.iosFlavors.keys) {
        expect(pbxprojContent.contains('Debug-$flavorName'), isTrue);
        expect(pbxprojContent.contains('Release-$flavorName'), isTrue);
      }
    });
  });
}
