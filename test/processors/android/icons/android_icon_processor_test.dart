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
import 'package:flutter_flavorizr/src/processors/android/icons/android_icon_processor.dart';
import 'package:flutter_flavorizr/src/utils/constants.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;
import 'package:sprintf/sprintf.dart';

import '../../../test_utils.dart';

void main() {
  late Flavorizr flavorizr;
  late Logger logger;
  late Directory originalDir;

  final sourceFixture = p.absolute(
      'test_resources/commons/image_resizer_processor_test/source.png');

  setUp(() {
    logger = TestUtils.quietLogger();
    flavorizr = TestUtils.parseFlavorizr('test_resources/pubspec');
    originalDir = Directory.current;
  });

  tearDown(() {
    Directory.current = originalDir;
  });

  test('Test AndroidIconProcessor generates one processor for each mipmap bucket', () {
    final processor = AndroidIconProcessor(
      sourceFixture,
      'apple',
      config: flavorizr,
      logger: logger,
    );

    expect(processor.processors.length, 5);
  });

  test(
      'Test AndroidIconProcessor resizes the icon into every mipmap folder when executed',
      () async {
    await TestUtils.withTempDir((dir) async {
      Directory.current = dir;

      final processor = AndroidIconProcessor(
        sourceFixture,
        'apple',
        config: flavorizr,
        logger: logger,
      );

      await processor.execute();

      for (final folder in [
        'mipmap-mdpi',
        'mipmap-hdpi',
        'mipmap-xhdpi',
        'mipmap-xxhdpi',
        'mipmap-xxxhdpi',
      ]) {
        final iconPath = sprintf(K.androidIconPath, ['apple', folder]);
        expect(File(iconPath).existsSync(), isTrue);
      }
    });
  });

}
