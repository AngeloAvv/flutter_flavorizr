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
import 'package:flutter_flavorizr/src/processors/ios/launch_screen/launch_assets.dart';
import 'package:test/test.dart';
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

  IOSDummyAssetsProcessor processorFor(String destination) =>
      IOSDummyAssetsProcessor(
        destination,
        'apple',
        config: flavorizr,
        logger: logger,
      );

  test(
    'IOSDummyAssetsProcessor.execute writes the LaunchImage set of the flavor, and no AppIcon set',
    () async {
      await TestUtils.withTempDir((dir) async {
        final destination = p.join(dir.path, 'destination');

        processorFor(destination).execute();

        final imageset = p.join(destination, 'appleLaunchImage.imageset');

        expect(
          File(p.join(imageset, 'Contents.json')).readAsStringSync(),
          launchImageContents,
        );
        for (final name in [
          'LaunchImage.png',
          'LaunchImage@2x.png',
          'LaunchImage@3x.png',
        ]) {
          expect(File(p.join(imageset, name)).readAsBytesSync(), isNotEmpty);
        }
        expect(
          Directory(
            p.join(destination, 'AppIcon-apple.appiconset'),
          ).existsSync(),
          isFalse,
        );
      });
    },
  );

  test(
    'IOSDummyAssetsProcessor leaves a launch image the project has for the flavor',
    () async {
      await TestUtils.withTempDir((dir) async {
        final destination = p.join(dir.path, 'destination');
        final mine = p.join(destination, 'appleLaunchImage.imageset');

        Directory(mine).createSync(recursive: true);
        File(p.join(mine, 'Contents.json')).writeAsStringSync('MINE');

        processorFor(destination).execute();

        expect(File(p.join(mine, 'Contents.json')).readAsStringSync(), 'MINE');
        expect(File(p.join(mine, 'LaunchImage.png')).existsSync(), isFalse);
      });
    },
  );
}
