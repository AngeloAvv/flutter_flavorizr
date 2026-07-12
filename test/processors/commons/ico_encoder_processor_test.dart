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
import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:flutter_flavorizr/src/processors/commons/ico_encoder_processor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

import '../../test_utils.dart';

void main() {
  late Flavorizr flavorizr;
  late Logger logger;

  final sourceFixture = p.absolute(
    'test_resources/commons/image_resizer_processor_test/source.png',
  );

  setUp(() {
    logger = TestUtils.quietLogger();
    flavorizr = TestUtils.parseFlavorizr('test_resources/pubspec');
  });

  test(
    'IcoEncoderProcessor.execute packs the source image into a multi-resolution .ico file',
    () async {
      await TestUtils.withTempDir((dir) async {
        final destination = p.join(dir.path, 'app_icon.ico');

        final processor = IcoEncoderProcessor(
          sourceFixture,
          destination,
          config: flavorizr,
          logger: logger,
        );

        processor.execute();

        final bytes = File(destination).readAsBytesSync();
        final decoder = IcoDecoder();
        final info = decoder.startDecode(bytes);

        expect(info, isNotNull);
        expect(info!.numFrames, 4);

        final sizes = <int>[];
        for (var i = 0; i < info.numFrames; i++) {
          final frame = decoder.decode(bytes, frame: i)!;
          sizes.add(frame.width);
        }

        expect(sizes..sort(), [16, 32, 48, 256]);
      });
    },
  );

  test(
    'Test IcoEncoderProcessor throws when source file does not exist',
    () async {
      await TestUtils.withTempDir((dir) async {
        final processor = IcoEncoderProcessor(
          p.join(dir.path, 'missing.png'),
          p.join(dir.path, 'app_icon.ico'),
          config: flavorizr,
          logger: logger,
        );

        expect(
          () => processor.execute(),
          throwsA(isA<FileNotFoundException>()),
        );
      });
    },
  );
}
