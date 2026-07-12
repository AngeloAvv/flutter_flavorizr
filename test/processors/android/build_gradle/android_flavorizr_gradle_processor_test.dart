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
import 'package:flutter_flavorizr/src/processors/android/build_gradle/android_flavorizr_gradle_processor.dart';
import 'package:flutter_flavorizr/src/processors/android/build_gradle/android_flavorizr_kotlin_processor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mason_logger/mason_logger.dart';

import '../../../test_utils.dart';

void main() {
  late Flavorizr flavorizr;
  late Logger logger;

  setUp(() {
    logger = TestUtils.quietLogger();
    flavorizr = TestUtils.parseFlavorizr('test_resources/pubspec');
  });

  test(
    'Test AndroidFlavorizrGradleProcessor picks the target path matching the first existing gradle file',
    () async {
      await TestUtils.withTempDir((dir) async {
        final legacyGradlePath = '${dir.path}/build.gradle';
        final kotlinGradlePath = '${dir.path}/build.gradle.kts';
        final legacyTargetPath = '${dir.path}/flavorizr.gradle';
        final kotlinTargetPath = '${dir.path}/flavorizr.gradle.kts';

        // Only the kotlin gradle file exists.
        File(kotlinGradlePath).writeAsStringSync('// kotlin gradle');

        final processor = AndroidFlavorizrGradleProcessor(
          [legacyGradlePath, kotlinGradlePath],
          [legacyTargetPath, kotlinTargetPath],
          [
            AndroidFlavorizrKotlinProcessor(config: flavorizr, logger: logger),
            AndroidFlavorizrKotlinProcessor(config: flavorizr, logger: logger),
          ],
          config: flavorizr,
          logger: logger,
        );

        // The constructor kicks off `execute()` without awaiting it, so give
        // the event loop a chance to flush the pending write before asserting.
        await Future<void>.delayed(Duration.zero);

        expect(processor.path, kotlinTargetPath);
        expect(File(kotlinTargetPath).existsSync(), isTrue);
      });
    },
  );

  test(
    'Test AndroidFlavorizrGradleProcessor throws FileNotFoundException when no gradle file exists',
    () {
      TestUtils.withTempDir((dir) {
        final legacyGradlePath = '${dir.path}/build.gradle';
        final kotlinGradlePath = '${dir.path}/build.gradle.kts';
        final legacyTargetPath = '${dir.path}/flavorizr.gradle';
        final kotlinTargetPath = '${dir.path}/flavorizr.gradle.kts';

        expect(
          () => AndroidFlavorizrGradleProcessor(
            [legacyGradlePath, kotlinGradlePath],
            [legacyTargetPath, kotlinTargetPath],
            [
              AndroidFlavorizrKotlinProcessor(
                config: flavorizr,
                logger: logger,
              ),
              AndroidFlavorizrKotlinProcessor(
                config: flavorizr,
                logger: logger,
              ),
            ],
            config: flavorizr,
            logger: logger,
          ),
          throwsA(isA<FileNotFoundException>()),
        );
      });
    },
  );
}
