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

import 'package:flutter_flavorizr/src/processors/android/google/firebase/android_firebase_processor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mason_logger/mason_logger.dart';

import '../../../../test_utils.dart';

void main() {
  late Logger logger;

  setUp(() {
    logger = TestUtils.quietLogger();
  });

  test(
    'Test AndroidFirebaseProcessor only queues flavors with an android firebase config',
    () {
      final flavorizr = TestUtils.parseFlavorizr(
        'test_resources/ios/ios_firebase_script_processor_test/single_flavor_pubspec',
      );

      final processor = AndroidFirebaseProcessor(
        destination: 'destination',
        config: flavorizr,
        logger: logger,
      );

      // Only the `apple` flavor declares an android firebase config.
      expect(processor.processors.length, 1);
    },
  );

  test(
    'Test AndroidFirebaseProcessor queues nothing when no flavor has an android firebase config',
    () {
      final flavorizr = TestUtils.parseFlavorizr('test_resources/pubspec');

      final processor = AndroidFirebaseProcessor(
        destination: 'destination',
        config: flavorizr,
        logger: logger,
      );

      expect(processor.processors, isEmpty);
    },
  );

  test(
    'Test AndroidFirebaseProcessor copies google-services.json for the flavor with firebase config',
    () async {
      await TestUtils.withTempDir((dir) async {
        final flavorizr = TestUtils.parseFlavorizr(
          'test_resources/ios/ios_firebase_script_processor_test/single_flavor_pubspec',
        );

        final firebaseConfigPath =
            flavorizr.androidFlavors['apple']!.android!.firebase!.config;
        Directory(firebaseConfigPath).parent.createSync(recursive: true);
        File(firebaseConfigPath).writeAsStringSync('{"fake": "config"}');

        final destination = '${dir.path}/destination';

        final processor = AndroidFirebaseProcessor(
          destination: destination,
          config: flavorizr,
          logger: logger,
        );

        await processor.execute();

        expect(
          File('$destination/apple/google-services.json').existsSync(),
          isTrue,
        );

        Directory('.firebase').deleteSync(recursive: true);
      });
    },
  );
}
