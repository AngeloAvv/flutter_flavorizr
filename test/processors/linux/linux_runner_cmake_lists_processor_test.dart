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
import 'package:flutter_flavorizr/src/processors/linux/linux_runner_cmake_lists_processor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mason_logger/mason_logger.dart';

import '../../test_utils.dart';

void main() {
  late Flavorizr flavorizr;
  late Logger logger;

  setUp(() {
    logger = TestUtils.quietLogger();
    flavorizr = TestUtils.parseFlavorizr('test_resources/linux/pubspec');
  });

  test(
    'LinuxRunnerCMakeListsProcessor.execute forwards FLUTTER_APP_FLAVOR as a preprocessor define',
    () {
      final content = File(
        'test_resources/linux/runner_cmake_lists_processor_test/CMakeLists.txt',
      ).readAsStringSync();

      final processor = LinuxRunnerCMakeListsProcessor(
        input: content,
        config: flavorizr,
        logger: logger,
      );
      final actual = processor.execute();

      TestUtils.expectMatchesFile(
        actual,
        'test_resources/linux/runner_cmake_lists_processor_test/CMakeLists_expected.txt',
      );
    },
  );

  test(
    'LinuxRunnerCMakeListsProcessor.execute is idempotent across multiple runs',
    () {
      final content = File(
        'test_resources/linux/runner_cmake_lists_processor_test/CMakeLists.txt',
      ).readAsStringSync();

      final firstRun = LinuxRunnerCMakeListsProcessor(
        input: content,
        config: flavorizr,
        logger: logger,
      ).execute();

      final secondRun = LinuxRunnerCMakeListsProcessor(
        input: firstRun,
        config: flavorizr,
        logger: logger,
      ).execute();

      expect(secondRun, firstRun);
    },
  );

  test(
    'Test malformed LinuxRunnerCMakeListsProcessor throws when APPLICATION_ID definition is missing',
    () {
      final processor = LinuxRunnerCMakeListsProcessor(
        input: 'project(runner LANGUAGES CXX)',
        config: flavorizr,
        logger: logger,
      );

      expect(() => processor.execute(), throwsException);
    },
  );
}
