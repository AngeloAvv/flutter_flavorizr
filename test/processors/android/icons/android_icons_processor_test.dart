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
import 'package:flutter_flavorizr/src/processors/android/icons/android_icons_processor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

import '../../../test_utils.dart';

void main() {
  late Flavorizr flavorizr;
  late Logger logger;
  late Directory originalDir;

  final sourceFixture = p.absolute(
      'test_resources/commons/image_resizer_processor_test/source.png');

  String buildPubspecYaml() => '''
name: flutterflavorizr_example
publish_to: 'none'

environment:
  sdk: "<4.0.0"

dependencies:
  flutter:
    sdk: flutter

flavorizr:
  app:
    android:
      flavorDimensions: "flavor-type"

  flavors:
    apple:
      app:
        name: "Apple App"
        icon: "$sourceFixture"
      android:
        applicationId: "com.example.apple"

    banana:
      app:
        name: "Banana App"
      android:
        applicationId: "com.example.banana"
        icon: "$sourceFixture"
        adaptiveIcon:
          foreground: "$sourceFixture"
          background: "$sourceFixture"

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
      'Test AndroidIconsProcessor queues icon processors for app/android icons and adaptive icon processors',
      () {
    TestUtils.withTempDir((dir) {
      final pubspecPath = '${dir.path}/pubspec.yaml';
      File(pubspecPath).writeAsStringSync(buildPubspecYaml());

      flavorizr = TestUtils.parseFlavorizr(pubspecPath.replaceAll('.yaml', ''));

      final processor = AndroidIconsProcessor(
        config: flavorizr,
        logger: logger,
      );

      // apple (app.icon) + banana (android.icon) = 2 AndroidIconProcessor
      // banana adaptiveIcon = 1 AndroidAdaptiveIconXmlProcessor + 1 AndroidAdaptiveIconsProcessor
      expect(processor.processors.length, 4);
    });
  });

  test('Test AndroidIconsProcessor queues nothing when no icon is configured', () {
    flavorizr = TestUtils.parseFlavorizr('test_resources/pubspec');

    final processor = AndroidIconsProcessor(
      config: flavorizr,
      logger: logger,
    );

    expect(processor.processors, isEmpty);
  });

  test('Test AndroidIconsProcessor executes without throwing', () async {
    await TestUtils.withTempDir((dir) async {
      final pubspecPath = '${dir.path}/pubspec.yaml';
      File(pubspecPath).writeAsStringSync(buildPubspecYaml());

      flavorizr = TestUtils.parseFlavorizr(pubspecPath.replaceAll('.yaml', ''));

      Directory.current = dir;

      final processor = AndroidIconsProcessor(
        config: flavorizr,
        logger: logger,
      );

      await processor.execute();
    });
  });

}
