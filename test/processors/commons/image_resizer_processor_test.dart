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

import 'package:flutter_flavorizr/src/exception/file_not_found_exception.dart';
import 'package:flutter_flavorizr/src/models/commons/size.dart';
import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:flutter_flavorizr/src/processors/commons/image_resizer_processor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart';
import 'package:mason_logger/mason_logger.dart';

import '../../test_utils.dart';

void main() {
  late Flavorizr flavorizr;
  late Logger logger;

  const sourceFixture =
      'test_resources/commons/image_resizer_processor_test/source.png';

  setUp(() {
    logger = TestUtils.quietLogger();
    flavorizr = TestUtils.parseFlavorizr('test_resources/pubspec');
  });

  test('Test ImageResizerProcessor resizes a real PNG image to the requested size', () {
    TestUtils.withTempDir((dir) {
      final destination = '${dir.path}/resized.png';

      final processor = ImageResizerProcessor(
        sourceFixture,
        destination,
        const Size(8, 8),
        config: flavorizr,
        logger: logger,
      );

      final result = processor.execute();

      expect(result.existsSync(), isTrue);

      final resized = decodeImage(File(destination).readAsBytesSync());
      expect(resized, isNotNull);
      expect(resized!.width, 8);
      expect(resized.height, 8);
    });
  });

  test('Test ImageResizerProcessor throws when source image file is missing', () {
    TestUtils.withTempDir((dir) {
      final source = '${dir.path}/missing.png';
      final destination = '${dir.path}/resized.png';

      final processor = ImageResizerProcessor(
        source,
        destination,
        const Size(8, 8),
        config: flavorizr,
        logger: logger,
      );

      // The underlying `File.readAsBytesSync()` call throws before the
      // processor's own `FileNotFoundException` (which only guards against a
      // malformed/undecodable image) has a chance to run.
      expect(() => processor.execute(), throwsA(isA<FileSystemException>()));
    });
  });

  test('Test ImageResizerProcessor throws FileNotFoundException when source file is not a decodable image', () {
    TestUtils.withTempDir((dir) {
      final source = '${dir.path}/not_an_image.png';
      final destination = '${dir.path}/resized.png';
      File(source).writeAsStringSync('this is not image data');

      final processor = ImageResizerProcessor(
        source,
        destination,
        const Size(8, 8),
        config: flavorizr,
        logger: logger,
      );

      expect(() => processor.execute(), throwsA(isA<FileNotFoundException>()));
    });
  });

}
