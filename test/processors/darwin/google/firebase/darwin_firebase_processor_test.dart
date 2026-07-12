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
import 'package:flutter_flavorizr/src/processors/darwin/google/firebase/darwin_firebase_processor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mason_logger/mason_logger.dart';

import '../../../../test_utils.dart';

void main() {
  late Flavorizr flavorizr;
  late Logger logger;

  const sourceFixture =
      'test_resources/ios/ios_firebase_script_processor_test/single_flavor_pubspec.yaml';

  setUp(() {
    logger = TestUtils.quietLogger();
    flavorizr = TestUtils.parseFlavorizr('test_resources/pubspec');
  });

  test(
      'Test DarwinFirebaseProcessor creates the flavor folder and copies GoogleService-Info.plist',
      () async {
    await TestUtils.withTempDir((dir) async {
      final destination = '${dir.path}/destination';

      final processor = DarwinFirebaseProcessor(
        sourceFixture,
        destination,
        'apple',
        config: flavorizr,
        logger: logger,
      );

      await processor.execute();

      final copied = File('$destination/apple/GoogleService-Info.plist');
      expect(copied.existsSync(), isTrue);
      expect(copied.readAsStringSync(), File(sourceFixture).readAsStringSync());
    });
  });

  test('Test DarwinFirebaseProcessor throws when source file is missing', () async {
    await TestUtils.withTempDir((dir) async {
      final destination = '${dir.path}/destination';

      final processor = DarwinFirebaseProcessor(
        '${dir.path}/missing.plist',
        destination,
        'apple',
        config: flavorizr,
        logger: logger,
      );

      await expectLater(processor.execute(), throwsA(anything));
    });
  });

}
