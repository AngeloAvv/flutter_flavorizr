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

import 'package:flutter_flavorizr/src/processors/android/huawei/agconnect/android_agconnect_processor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mason_logger/mason_logger.dart';

import '../../../../test_utils.dart';

void main() {
  late Logger logger;

  setUp(() {
    logger = TestUtils.quietLogger();
  });

  test(
      'Test AndroidAGConnectProcessor only queues flavors with an android agconnect config',
      () {
    final flavorizr = TestUtils.parseFlavorizr(
      'test_resources/android/agconnect_processor_test/pubspec',
    );

    final processor = AndroidAGConnectProcessor(
      destination: 'destination',
      config: flavorizr,
      logger: logger,
    );

    expect(processor.processors.length, 1);
  });

  test(
      'Test AndroidAGConnectProcessor queues nothing when no flavor has an android agconnect config',
      () {
    final flavorizr = TestUtils.parseFlavorizr('test_resources/pubspec');

    final processor = AndroidAGConnectProcessor(
      destination: 'destination',
      config: flavorizr,
      logger: logger,
    );

    expect(processor.processors, isEmpty);
  });

  test(
      'Test AndroidAGConnectProcessor copies agconnect-services.json for the flavor with agconnect config',
      () async {
    await TestUtils.withTempDir((dir) async {
      final flavorizr = TestUtils.parseFlavorizr(
        'test_resources/android/agconnect_processor_test/pubspec',
      );

      final destination = '${dir.path}/destination';

      final processor = AndroidAGConnectProcessor(
        destination: destination,
        config: flavorizr,
        logger: logger,
      );

      await processor.execute();

      expect(
        File('$destination/apple/agconnect-services.json').existsSync(),
        isTrue,
      );
    });
  });

}
