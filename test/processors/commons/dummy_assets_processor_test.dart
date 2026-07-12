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
import 'package:flutter_flavorizr/src/parser/models/flavors/commons/os.dart';
import 'package:flutter_flavorizr/src/processors/commons/dummy_assets_processor.dart';
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

  test('Test DummyAssetsProcessor copies folder when generateDummyAssets is true', () {
    TestUtils.withTempDir((dir) {
      final source = '${dir.path}/source';
      final destination = '${dir.path}/destination';
      Directory(source).createSync(recursive: true);
      File('$source/asset.png').writeAsStringSync('asset content');

      const os = OS(generateDummyAssets: true);

      final processor = DummyAssetsProcessor(
        source,
        destination,
        os,
        config: flavorizr,
        logger: logger,
      );

      processor.execute();

      expect(File('$destination/asset.png').readAsStringSync(), 'asset content');
    });
  });

  test('Test DummyAssetsProcessor skips copy when generateDummyAssets is false', () {
    TestUtils.withTempDir((dir) {
      final source = '${dir.path}/source';
      final destination = '${dir.path}/destination';
      Directory(source).createSync(recursive: true);
      File('$source/asset.png').writeAsStringSync('asset content');

      const os = OS(generateDummyAssets: false);

      final processor = DummyAssetsProcessor(
        source,
        destination,
        os,
        config: flavorizr,
        logger: logger,
      );

      processor.execute();

      expect(Directory(destination).existsSync(), isFalse);
    });
  });

}
