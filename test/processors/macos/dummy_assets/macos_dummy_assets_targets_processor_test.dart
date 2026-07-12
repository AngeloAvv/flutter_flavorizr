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
import 'package:flutter_flavorizr/src/processors/macos/dummy_assets/macos_dummy_assets_processor.dart';
import 'package:flutter_flavorizr/src/processors/macos/dummy_assets/macos_dummy_assets_targets_processor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:io/io.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

import '../../../test_utils.dart';

void main() {
  late Flavorizr flavorizr;
  late Logger logger;

  setUp(() {
    logger = TestUtils.quietLogger();
    flavorizr = TestUtils.parseFlavorizr(
      'test_resources/macos/dummy_assets_processor_test/pubspec',
    );
  });

  test(
      'MacOSDummyAssetsTargetsProcessor wires one MacOSDummyAssetsProcessor per macOS flavor',
      () {
    final processor = MacOSDummyAssetsTargetsProcessor(
      'source',
      'destination',
      config: flavorizr,
      logger: logger,
    );

    expect(processor.processors.length, flavorizr.macosFlavors.length);
    expect(
        processor.processors, everyElement(isA<MacOSDummyAssetsProcessor>()));
  });

  test(
      'MacOSDummyAssetsTargetsProcessor.execute generates dummy assets for every macOS flavor',
      () {
    TestUtils.withTempDir((dir) async {
      final source = p.join(dir.path, 'source');
      final destination = p.join(dir.path, 'destination');
      Directory(source).createSync(recursive: true);

      copyPathSync(
        'test_resources/macos/dummy_assets_processor_test/AppIcon.appiconset',
        p.join(source, 'AppIcon.appiconset'),
      );

      final processor = MacOSDummyAssetsTargetsProcessor(
        source,
        destination,
        config: flavorizr,
        logger: logger,
      );

      await processor.execute();

      for (final flavorName in flavorizr.macosFlavors.keys) {
        expect(
          Directory(p.join(destination, 'AppIcon-$flavorName.appiconset'))
              .existsSync(),
          isTrue,
        );
      }
    });
  });
}
