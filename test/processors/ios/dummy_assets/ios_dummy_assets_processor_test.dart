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
import 'package:flutter_flavorizr/src/processors/ios/dummy_assets/ios_dummy_assets_processor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:io/io.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

import '../../../test_utils.dart';

void main() {
  late FlavorizrConfig flavorizr;
  late Logger logger;

  setUp(() {
    logger = TestUtils.quietLogger();
    flavorizr = TestUtils.parseFlavorizr(
      'test_resources/ios/dummy_assets_processor_test/pubspec',
    );
  });

  test(
    'IOSDummyAssetsProcessor.execute copies the LaunchImage set into a flavor-specific folder and no AppIcon set',
    () async {
      await TestUtils.withTempDir((dir) async {
        final source = p.join(dir.path, 'source');
        final destination = p.join(dir.path, 'destination');
        Directory(source).createSync(recursive: true);

        copyPathSync(
          'test_resources/ios/dummy_assets_processor_test/AppIcon.appiconset',
          p.join(source, 'AppIcon.appiconset'),
        );
        copyPathSync(
          'test_resources/ios/dummy_assets_processor_test/LaunchImage.imageset',
          p.join(source, 'LaunchImage.imageset'),
        );

        final processor = IOSDummyAssetsProcessor(
          source,
          destination,
          'apple',
          config: flavorizr,
          logger: logger,
        );

        await processor.execute();

        expect(
          Directory(
            p.join(destination, 'AppIcon-apple.appiconset'),
          ).existsSync(),
          isFalse,
        );
        expect(
          Directory(
            p.join(destination, 'appleLaunchImage.imageset'),
          ).existsSync(),
          isTrue,
        );
      });
    },
  );

  test(
    'IOSDummyAssetsProcessor leaves a launch image the project has for the flavor',
    () async {
      await TestUtils.withTempDir((dir) async {
        final source = p.join(dir.path, 'source');
        final destination = p.join(dir.path, 'destination');
        final mine = p.join(destination, 'appleLaunchImage.imageset');

        copyPathSync(
          'test_resources/ios/dummy_assets_processor_test/LaunchImage.imageset',
          p.join(source, 'LaunchImage.imageset'),
        );
        Directory(mine).createSync(recursive: true);
        File(p.join(mine, 'Contents.json')).writeAsStringSync('MINE');

        final processor = IOSDummyAssetsProcessor(
          source,
          destination,
          'apple',
          config: flavorizr,
          logger: logger,
        );

        expect(processor.processors, isEmpty);

        await processor.execute();

        expect(File(p.join(mine, 'Contents.json')).readAsStringSync(), 'MINE');
      });
    },
  );
}
