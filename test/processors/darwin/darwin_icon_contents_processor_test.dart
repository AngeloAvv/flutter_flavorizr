/*
 * Copyright (c) 2026 Angelo Cassano
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

import 'package:flutter_flavorizr/src/models/darwin/icon/darwin_icon.dart';
import 'package:flutter_flavorizr/src/models/darwin/icon/darwin_idiom.dart';
import 'package:flutter_flavorizr/src/models/ios/ios_icon.dart';
import 'package:flutter_flavorizr/src/models/macos/macos_icon.dart';
import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:flutter_flavorizr/src/parser/parser.dart';
import 'package:flutter_flavorizr/src/processors/darwin/icons/darwin_icon_contents_processor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mason_logger/mason_logger.dart';

void main() {
  late List<DarwinIcon> icons;

  late Flavorizr flavorizr;
  late Logger logger;

  setUp(() {
    logger = Logger(level: Level.quiet);
    Parser parser = const Parser(
      pubspecPath: 'test_resources/pubspec',
      flavorizrPath: 'test_resources/non_existent',
    );

    try {
      flavorizr = parser.parse();
    } catch (e) {
      fail(e.toString());
    }
  });

  tearDown(() {});

  group('Test on iOS', () {
    setUp(() {
      icons = [
        IosIcon(size: 20, idiom: DarwinIdiom.iPhone, scale: 2),
        IosIcon(size: 20, idiom: DarwinIdiom.iPhone, scale: 3),
        IosIcon(size: 29, idiom: DarwinIdiom.iPhone, scale: 1),
        IosIcon(size: 29, idiom: DarwinIdiom.iPhone, scale: 2),
        IosIcon(size: 29, idiom: DarwinIdiom.iPhone, scale: 3),
        IosIcon(size: 40, idiom: DarwinIdiom.iPhone, scale: 2),
        IosIcon(size: 40, idiom: DarwinIdiom.iPhone, scale: 3),
        IosIcon(size: 60, idiom: DarwinIdiom.iPhone, scale: 2),
        IosIcon(size: 60, idiom: DarwinIdiom.iPhone, scale: 3),
        IosIcon(size: 20, idiom: DarwinIdiom.iPad, scale: 1),
        IosIcon(size: 20, idiom: DarwinIdiom.iPad, scale: 2),
        IosIcon(size: 29, idiom: DarwinIdiom.iPad, scale: 1),
        IosIcon(size: 29, idiom: DarwinIdiom.iPad, scale: 2),
        IosIcon(size: 40, idiom: DarwinIdiom.iPad, scale: 1),
        IosIcon(size: 40, idiom: DarwinIdiom.iPad, scale: 2),
        IosIcon(size: 76, idiom: DarwinIdiom.iPad, scale: 1),
        IosIcon(size: 76, idiom: DarwinIdiom.iPad, scale: 2),
        IosIcon(size: 83.5, idiom: DarwinIdiom.iPad, scale: 2),
        IosIcon(size: 1024, idiom: DarwinIdiom.iosMarketing, scale: 1),
      ];
    });

    test('processor.execute should generate correct Contents.json', () {
      final processor = DarwinIconContentsProcessor(
        icons.toSet(),
        config: flavorizr,
        logger: logger,
      );
      final actual = processor.execute();
      final json = jsonDecode(actual);

      expect(json['images'], isNotEmpty);
      expect(json['info'], isNotNull);
      expect(json['info']['version'], 1);
      expect(json['info']['author'], 'xcode');

      for (var i = 0; i < icons.length; i++) {
        final iconJson = icons[i].toJson();
        final actualIconJson = json['images'][i];

        expect(actualIconJson['size'], iconJson['size']);
        expect(actualIconJson['idiom'], iconJson['idiom']);
        expect(actualIconJson['scale'], iconJson['scale']);
        expect(actualIconJson['filename'], iconJson['filename']);
      }
    });
  });

  group('Test on macOS', () {
    setUp(() {
      icons = [
        MacosIcon(size: 16, idiom: DarwinIdiom.mac, scale: 1),
        MacosIcon(size: 16, idiom: DarwinIdiom.mac, scale: 2),
        MacosIcon(size: 32, idiom: DarwinIdiom.mac, scale: 1),
        MacosIcon(size: 32, idiom: DarwinIdiom.mac, scale: 2),
        MacosIcon(size: 128, idiom: DarwinIdiom.mac, scale: 1),
        MacosIcon(size: 128, idiom: DarwinIdiom.mac, scale: 2),
        MacosIcon(size: 256, idiom: DarwinIdiom.mac, scale: 1),
        MacosIcon(size: 256, idiom: DarwinIdiom.mac, scale: 2),
        MacosIcon(size: 512, idiom: DarwinIdiom.mac, scale: 1),
        MacosIcon(size: 512, idiom: DarwinIdiom.mac, scale: 2),
      ];
    });

    test('processor.execute should generate correct Contents.json', () {
      final processor = DarwinIconContentsProcessor(
        icons.toSet(),
        config: flavorizr,
        logger: logger,
      );
      final actual = processor.execute();
      final json = jsonDecode(actual);

      expect(json['images'], isNotEmpty);
      expect(json['info'], isNotNull);
      expect(json['info']['version'], 1);
      expect(json['info']['author'], 'xcode');

      for (var i = 0; i < icons.length; i++) {
        final iconJson = icons[i].toJson();
        final actualIconJson = json['images'][i];

        expect(actualIconJson['size'], iconJson['size']);
        expect(actualIconJson['idiom'], iconJson['idiom']);
        expect(actualIconJson['scale'], iconJson['scale']);
        expect(actualIconJson['filename'], iconJson['filename']);
      }
    });
  });
}
