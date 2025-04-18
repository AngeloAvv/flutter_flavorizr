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

import 'package:flutter_flavorizr/src/exception/file_not_found_exception.dart';
import 'package:flutter_flavorizr/src/processors/commons/abstract_file_string_processor.dart';

class RuntimeFileStringProcessor extends AbstractFileStringProcessor {
  RuntimeFileStringProcessor(
    super.path,
    super.processor, {
    required super.config,
    required super.logger,
  });

  @override
  void execute() {
    if (!file.existsSync()) {
      logger.detail(
        '[$RuntimeFileStringProcessor] File `$path` not found, ',
        style: logger.theme.err,
      );

      throw FileNotFoundException(path);
    }

    logger.detail(
      '[$RuntimeFileStringProcessor] Reading from file `$path`',
    );

    processor.input = file.readAsStringSync();

    logger.detail(
      '[$RuntimeFileStringProcessor] File `$path` read',
      style: logger.theme.success,
    );

    super.execute();
  }

  @override
  String toString() =>
      "FileProcessor: {path: $path, processor: $processor}";
}
