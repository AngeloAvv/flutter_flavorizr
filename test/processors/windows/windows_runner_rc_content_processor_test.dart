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
import 'package:flutter_flavorizr/src/processors/windows/windows_runner_rc_content_processor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mason_logger/mason_logger.dart';

import '../../test_utils.dart';

void main() {
  late Flavorizr flavorizr;
  late Logger logger;

  setUp(() {
    logger = TestUtils.quietLogger();
    flavorizr = TestUtils.parseFlavorizr('test_resources/windows/pubspec');
  });

  test(
    'WindowsRunnerRcContentProcessor.execute templates the icon reference and window title strings',
    () {
      final content = File(
        'test_resources/windows/runner_rc_content_processor_test/Runner.rc',
      ).readAsStringSync();

      final processor = WindowsRunnerRcContentProcessor(
        input: content,
        config: flavorizr,
        logger: logger,
      );
      final actual = processor.execute();

      TestUtils.expectMatchesFile(
        actual,
        'test_resources/windows/runner_rc_content_processor_test/Runner_expected.rc',
      );
    },
  );

  test(
    'WindowsRunnerRcContentProcessor.execute is idempotent across multiple runs',
    () {
      final content = File(
        'test_resources/windows/runner_rc_content_processor_test/Runner.rc',
      ).readAsStringSync();

      final firstRun = WindowsRunnerRcContentProcessor(
        input: content,
        config: flavorizr,
        logger: logger,
      ).execute();

      final secondRun = WindowsRunnerRcContentProcessor(
        input: firstRun,
        config: flavorizr,
        logger: logger,
      ).execute();

      expect(secondRun, firstRun);
    },
  );

  test(
    'Test malformed WindowsRunnerRcContentProcessor throws when icon reference is missing',
    () {
      final processor = WindowsRunnerRcContentProcessor(
        input: 'VS_VERSION_INFO VERSIONINFO',
        config: flavorizr,
        logger: logger,
      );

      expect(() => processor.execute(), throwsException);
    },
  );

  test(
    'Test malformed WindowsRunnerRcContentProcessor throws when FileDescription/ProductName are missing',
    () {
      final processor = WindowsRunnerRcContentProcessor(
        input: 'IDI_APP_ICON            ICON                    "resources\\\\app_icon.ico"',
        config: flavorizr,
        logger: logger,
      );

      expect(() => processor.execute(), throwsException);
    },
  );
}
