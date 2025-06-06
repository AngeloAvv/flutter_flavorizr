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
import 'package:flutter_flavorizr/src/processors/commons/abstract_processor.dart';
import 'package:mason_logger/mason_logger.dart';

class NewFolderProcessor extends AbstractProcessor {
  final String path;
  late Directory dir;

  NewFolderProcessor(
    this.path, {
    required Flavorizr config,
    required Logger logger,
  }) : super(config, logger: logger);

  @override
  execute() {
    dir = Directory(path);

    if (!dir.existsSync()) {
      logger.info(
        '[$NewFolderProcessor] Creating directory $path',
      );

      dir.createSync(recursive: true);

      logger.detail(
        '[$NewFolderProcessor] Directory $path created successfully',
        style: logger.theme.success,
      );
    }
  }

  @override
  String toString() {
    return 'NewFolderProcessor: Creating directory $path';
  }
}
