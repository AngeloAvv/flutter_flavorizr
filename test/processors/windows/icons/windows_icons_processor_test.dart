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
import 'package:flutter_flavorizr/src/processors/windows/icons/windows_icons_processor.dart';
import 'package:flutter_flavorizr/src/utils/constants.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

import '../../../test_utils.dart';

void main() {
  late Flavorizr flavorizr;
  late Logger logger;
  late Directory originalDir;

  final sourceFixture = p.absolute(
    'test_resources/commons/image_resizer_processor_test/source.png',
  );

  String buildPubspecYaml() => '''
name: flutterflavorizr_example
publish_to: 'none'

environment:
  sdk: "<4.0.0"

dependencies:
  flutter:
    sdk: flutter

flavorizr:
  flavors:
    apple:
      app:
        name: "Apple App"
      windows:
        icon: '$sourceFixture'

    banana:
      app:
        name: "Banana App"
      windows: {}

flutter:
  uses-material-design: true
''';

  setUp(() {
    logger = TestUtils.quietLogger();
    originalDir = Directory.current;
  });

  tearDown(() {
    Directory.current = originalDir;
  });

  test(
    'Test WindowsIconsProcessor queues one processor per flavor with a configured icon',
    () {
      TestUtils.withTempDir((dir) {
        final pubspecPath = '${dir.path}/pubspec.yaml';
        File(pubspecPath).writeAsStringSync(buildPubspecYaml());

        flavorizr = TestUtils.parseFlavorizr(pubspecPath.replaceAll('.yaml', ''));

        final processor = WindowsIconsProcessor(config: flavorizr, logger: logger);

        expect(processor.processors.length, 1);
      });
    },
  );

  test(
    'Test WindowsIconsProcessor queues nothing when no flavor has an icon configured',
    () {
      flavorizr = TestUtils.parseFlavorizr('test_resources/windows/pubspec');

      final processor = WindowsIconsProcessor(config: flavorizr, logger: logger);

      expect(processor.processors, isEmpty);
    },
  );

  test(
    'Test WindowsIconsProcessor writes the .ico for the flavor with a configured icon',
    () async {
      await TestUtils.withTempDir((dir) async {
        final pubspecPath = '${dir.path}/pubspec.yaml';
        File(pubspecPath).writeAsStringSync(buildPubspecYaml());

        flavorizr = TestUtils.parseFlavorizr(pubspecPath.replaceAll('.yaml', ''));

        Directory.current = dir;

        await WindowsIconsProcessor(config: flavorizr, logger: logger).execute();

        expect(File('${K.windowsIconsPath}/apple.ico').existsSync(), isTrue);
        expect(File('${K.windowsIconsPath}/banana.ico').existsSync(), isFalse);
      });
    },
  );
}
