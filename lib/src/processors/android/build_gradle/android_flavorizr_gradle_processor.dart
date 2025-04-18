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
import 'package:flutter_flavorizr/src/processors/commons/abstract_file_string_processor.dart';
import 'package:flutter_flavorizr/src/processors/commons/string_processor.dart';
import 'package:mason_logger/mason_logger.dart';

class AndroidFlavorizrGradleProcessor extends AbstractFileStringProcessor {
  AndroidFlavorizrGradleProcessor(
    List<String> gradlePaths,
    List<String> createTargetPaths,
    List<StringProcessor> processors, {
    required super.config,
    required Logger logger,
  })  : assert(gradlePaths.length == processors.length),
        super(
          _findTargetPathByExistingFile(
              gradlePaths, createTargetPaths, processors),
          _findProcessor(gradlePaths, createTargetPaths, processors),
          logger: logger,
        ) {
    file.createSync(recursive: true);
    super.execute();
  }

  static String _findTargetPathByExistingFile(
    List<String> gradlePaths,
    List<String> createTargetPaths,
    List<StringProcessor> processors,
  ) {
    for (int i = 0; i < gradlePaths.length; i++) {
      final path = gradlePaths[i];
      final file = File(path);
      if (file.existsSync()) {
        return createTargetPaths[i];
      }
    }
    throw FileNotFoundException(gradlePaths.toString());
  }

  static StringProcessor _findProcessor(
    List<String> gradlePaths,
    List<String> createTargetPaths,
    List<StringProcessor> processors,
  ) {
    for (int i = 0; i < gradlePaths.length; i++) {
      final path = gradlePaths[i];
      final file = File(path);
      if (file.existsSync()) {
        return processors[i];
      }
    }
    throw FileNotFoundException(gradlePaths.toString());
  }
}
