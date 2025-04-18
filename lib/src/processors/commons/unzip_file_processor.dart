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

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:flutter_flavorizr/src/processors/commons/abstract_file_processor.dart';

class UnzipFileProcessor extends AbstractFileProcessor {
  final String _source;
  final String _destination;

  UnzipFileProcessor(
    this._source,
    this._destination, {
    required super.config,
    required super.logger,
  }) : super(_source);

  @override
  void execute() {
    // Read the Zip file from disk.
    logger.detail(
      '[$UnzipFileProcessor] Reading bytes from file `${file.path}`',
    );
    final bytes = file.readAsBytesSync();
    logger.detail(
      '[$UnzipFileProcessor] Bytes read from file `${file.path}`',
      style: logger.theme.success,
    );

    // Decode the Zip file
    logger.detail(
      '[$UnzipFileProcessor] Decoding bytes from file `${file.path}`',
    );
    final archive = ZipDecoder().decodeBytes(bytes);
    logger.detail(
      '[$UnzipFileProcessor] Bytes decoded from file `${file.path}`',
      style: logger.theme.success,
    );

    // Extract the contents of the Zip archive to disk.
    for (final file in archive) {
      final String fileName = '$_destination/${file.name}';
      if (file.isFile) {
        logger.detail(
          '[$UnzipFileProcessor] Extracting file `$fileName`',
        );

        final data = file.content as List<int>;
        File(fileName)
          ..createSync(recursive: true)
          ..writeAsBytesSync(data);

        logger.detail(
          '[$UnzipFileProcessor] File `$fileName` extracted',
          style: logger.theme.success,
        );
      } else {
        logger.detail(
          '[$UnzipFileProcessor] Creating directory `$fileName`',
        );

        Directory(fileName).createSync(recursive: true);

        logger.detail(
          '[$UnzipFileProcessor] Directory `$fileName` created',
          style: logger.theme.success,
        );
      }
    }
  }

  @override
  String toString() => 'UnzipFileProcessor: {source: $_source, destination: $_destination}';
}
