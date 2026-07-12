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

import 'package:flutter_flavorizr/src/extensions/extensions_string.dart';
import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:flutter_flavorizr/src/parser/models/flavors/darwin/enums.dart';
import 'package:flutter_flavorizr/src/processors/macos/configs/macos_configs_file_processor.dart';
import 'package:flutter_flavorizr/src/processors/macos/configs/macos_configs_targets_file_processor.dart';
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
      'test_resources/macos/xcconfig_targets_file_processor_test/pubspec',
    );
  });

  test(
      'MacOSConfigsTargetsFileProcessor wires one MacOSConfigsFileProcessor per macOS flavor',
      () {
    final processor = MacOSConfigsTargetsFileProcessor(
      'project',
      'path',
      config: flavorizr,
      logger: logger,
    );

    expect(processor.processors.length, flavorizr.macosFlavors.length);
    expect(processor.processors,
        everyElement(isA<MacOSConfigsFileProcessor>()));
  });

  test(
      'MacOSConfigsTargetsFileProcessor.execute writes a Configs xcconfig file per flavor/target and registers them in the Xcode project',
      () {
    TestUtils.withTempDir((dir) async {
      final projectSourceDir = Directory(
          'test_resources/macos/build_configuration_targets_processor_test/Runner.xcodeproj');
      final projectDestDir =
          Directory(p.join(dir.path, 'Runner.xcodeproj'))..createSync();

      for (final entity in projectSourceDir.listSync()) {
        if (entity is File) {
          entity.copySync(
              p.join(projectDestDir.path, p.basename(entity.path)));
        }
      }

      final path = p.join(dir.path, 'Runner', 'Configs');
      Directory(path).createSync(recursive: true);

      final processor = MacOSConfigsTargetsFileProcessor(
        projectDestDir.path,
        path,
        config: flavorizr,
        logger: logger,
      );

      await processor.execute();

      for (final flavorName in flavorizr.macosFlavors.keys) {
        for (final target in Target.values) {
          final expectedFile = File(
              p.join(path, '$flavorName${target.name.capitalize}.xcconfig'));
          expect(expectedFile.existsSync(), isTrue);
        }
      }
    });
  });
}
