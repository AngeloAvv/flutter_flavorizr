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

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:flutter_flavorizr/src/processors/commons/unzip_file_processor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mason_logger/mason_logger.dart';

import '../../test_utils.dart';

void main() {
  late Flavorizr flavorizr;
  late Logger logger;

  setUp(() {
    logger = TestUtils.quietLogger();
    flavorizr = TestUtils.parseFlavorizr('test_resources/pubspec');
  });

  test('Test UnzipFileProcessor extracts files and directories from a zip archive', () {
    TestUtils.withTempDir((dir) {
      final zipPath = '${dir.path}/archive.zip';
      final destination = '${dir.path}/extracted';

      final archive = Archive();
      final fileData = utf8.encode('hello from zip');
      archive.addFile(ArchiveFile('file.txt', fileData.length, fileData));
      final nestedData = utf8.encode('nested content');
      archive.addFile(ArchiveFile('nested/inner.txt', nestedData.length, nestedData));

      final zipBytes = ZipEncoder().encode(archive);
      File(zipPath).writeAsBytesSync(zipBytes);

      final processor = UnzipFileProcessor(
        zipPath,
        destination,
        config: flavorizr,
        logger: logger,
      );

      processor.execute();

      expect(File('$destination/file.txt').readAsStringSync(), 'hello from zip');
      expect(
        File('$destination/nested/inner.txt').readAsStringSync(),
        'nested content',
      );
    });
  });

  test('Test UnzipFileProcessor throws when zip source does not exist', () {
    TestUtils.withTempDir((dir) {
      final zipPath = '${dir.path}/missing.zip';
      final destination = '${dir.path}/extracted';

      final processor = UnzipFileProcessor(
        zipPath,
        destination,
        config: flavorizr,
        logger: logger,
      );

      expect(() => processor.execute(), throwsA(isA<FileSystemException>()));
    });
  });

}
