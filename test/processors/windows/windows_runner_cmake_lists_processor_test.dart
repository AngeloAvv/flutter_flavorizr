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

import 'package:flutter_flavorizr/src/exception/malformed_resource_exception.dart';
import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:flutter_flavorizr/src/processors/windows/windows_runner_cmake_lists_processor.dart';
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
    'WindowsRunnerCMakeListsProcessor.execute injects per-flavor icon/window title overrides and configure_file calls',
    () {
      final content = File(
        'test_resources/windows/runner_cmake_lists_processor_test/CMakeLists.txt',
      ).readAsStringSync();

      final processor = WindowsRunnerCMakeListsProcessor(
        input: content,
        config: flavorizr,
        logger: logger,
      );
      final actual = processor.execute();

      TestUtils.expectMatchesFile(
        actual,
        'test_resources/windows/runner_cmake_lists_processor_test/CMakeLists_expected.txt',
      );
    },
  );

  test(
    'WindowsRunnerCMakeListsProcessor.execute is idempotent across multiple runs',
    () {
      final content = File(
        'test_resources/windows/runner_cmake_lists_processor_test/CMakeLists.txt',
      ).readAsStringSync();

      final firstRun = WindowsRunnerCMakeListsProcessor(
        input: content,
        config: flavorizr,
        logger: logger,
      ).execute();

      final secondRun = WindowsRunnerCMakeListsProcessor(
        input: firstRun,
        config: flavorizr,
        logger: logger,
      ).execute();

      expect(secondRun, firstRun);
    },
  );

  test(
    'Test malformed WindowsRunnerCMakeListsProcessor throws when add_executable is missing',
    () {
      final processor = WindowsRunnerCMakeListsProcessor(
        input: 'project(runner LANGUAGES CXX)',
        config: flavorizr,
        logger: logger,
      );

      expect(
        () => processor.execute(),
        throwsA(isA<MalformedResourceException>()),
      );
    },
  );
}
