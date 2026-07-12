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
import 'package:flutter_flavorizr/src/processors/commons/dynamic_file_string_processor.dart';
import 'package:flutter_flavorizr/src/processors/commons/string_processor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mason_logger/mason_logger.dart';

import '../../test_utils.dart';

class _StubStringProcessor extends StringProcessor {
  _StubStringProcessor({
    required super.config,
    required super.logger,
  });

  @override
  String execute() => 'processed(${input ?? ''})';
}

void main() {
  late Flavorizr flavorizr;
  late Logger logger;

  setUp(() {
    logger = TestUtils.quietLogger();
    flavorizr = TestUtils.parseFlavorizr('test_resources/pubspec');
  });

  test('Test DynamicFileStringProcessor reads and rewrites content when file exists', () async {
    await TestUtils.withTempDir((dir) async {
      final path = '${dir.path}/existing.txt';
      File(path).writeAsStringSync('original content');

      final processor = _StubStringProcessor(config: flavorizr, logger: logger);

      final fileProcessor = DynamicFileStringProcessor(
        path,
        processor,
        config: flavorizr,
        logger: logger,
      );

      await fileProcessor.execute();

      expect(processor.input, 'original content');
      expect(File(path).readAsStringSync(), 'processed(original content)');
    });
  });

  test('Test DynamicFileStringProcessor is a no-op when file does not exist', () async {
    await TestUtils.withTempDir((dir) async {
      final path = '${dir.path}/missing.txt';

      final processor = _StubStringProcessor(config: flavorizr, logger: logger);

      final fileProcessor = DynamicFileStringProcessor(
        path,
        processor,
        config: flavorizr,
        logger: logger,
      );

      await fileProcessor.execute();

      expect(File(path).existsSync(), isFalse);
      expect(processor.input, isNull);
    });
  });

}
