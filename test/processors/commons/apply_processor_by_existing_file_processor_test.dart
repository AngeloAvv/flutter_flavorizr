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
import 'package:flutter_flavorizr/src/processors/commons/apply_processor_by_existing_file_processor.dart';
import 'package:flutter_flavorizr/src/processors/commons/string_processor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mason_logger/mason_logger.dart';

import '../../test_utils.dart';

class _StubStringProcessor extends StringProcessor {
  final String tag;

  _StubStringProcessor(
    this.tag, {
    required super.config,
    required super.logger,
  });

  @override
  String execute() => '$tag(${input ?? ''})';
}

void main() {
  late Flavorizr flavorizr;
  late Logger logger;

  setUp(() {
    logger = TestUtils.quietLogger();
    flavorizr = TestUtils.parseFlavorizr('test_resources/pubspec');
  });

  test('Test ApplyProcessorByExistingFileProcessor picks the first existing path and its matching processor', () async {
    await TestUtils.withTempDir((dir) async {
      final missingPath = '${dir.path}/missing.txt';
      final existingPath = '${dir.path}/existing.txt';
      File(existingPath).writeAsStringSync('found content');

      final missingProcessor = _StubStringProcessor('missing', config: flavorizr, logger: logger);
      final existingProcessor = _StubStringProcessor('existing', config: flavorizr, logger: logger);

      final fileProcessor = ApplyProcessorByExistingFileProcessor(
        [missingPath, existingPath],
        [missingProcessor, existingProcessor],
        config: flavorizr,
        logger: logger,
      );

      expect(fileProcessor.path, existingPath);
      expect(existingProcessor.input, 'found content');

      await fileProcessor.execute();

      expect(File(existingPath).readAsStringSync(), 'existing(found content)');
    });
  });

  test('Test ApplyProcessorByExistingFileProcessor throws when no path exists', () {
    TestUtils.withTempDir((dir) {
      final firstMissing = '${dir.path}/missing1.txt';
      final secondMissing = '${dir.path}/missing2.txt';

      final processors = [
        _StubStringProcessor('first', config: flavorizr, logger: logger),
        _StubStringProcessor('second', config: flavorizr, logger: logger),
      ];

      expect(
        () => ApplyProcessorByExistingFileProcessor(
          [firstMissing, secondMissing],
          processors,
          config: flavorizr,
          logger: logger,
        ),
        throwsA(isA<FileNotFoundException>()),
      );
    });
  });

  test('Test ApplyProcessorByExistingFileProcessor asserts when paths and processors length mismatch', () {
    TestUtils.withTempDir((dir) {
      final existingPath = '${dir.path}/existing.txt';
      File(existingPath).writeAsStringSync('content');

      expect(
        () => ApplyProcessorByExistingFileProcessor(
          [existingPath],
          [
            _StubStringProcessor('a', config: flavorizr, logger: logger),
            _StubStringProcessor('b', config: flavorizr, logger: logger),
          ],
          config: flavorizr,
          logger: logger,
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
