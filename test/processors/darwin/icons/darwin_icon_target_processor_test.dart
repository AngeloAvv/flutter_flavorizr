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

import 'package:flutter_flavorizr/src/models/darwin/icon/darwin_idiom.dart';
import 'package:flutter_flavorizr/src/models/ios/ios_icon.dart';
import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:flutter_flavorizr/src/processors/darwin/icons/darwin_icon_target_processor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

import '../../../test_utils.dart';

class _TestDarwinIconTargetProcessor extends DarwinIconTargetProcessor {
  _TestDarwinIconTargetProcessor(
    super.source, {
    required super.flavorName,
    required super.iconSet,
    required super.appIconPath,
    required super.config,
    required super.logger,
  });
}

void main() {
  late Flavorizr flavorizr;
  late Logger logger;

  final sourceFixture = p.absolute(
      'test_resources/commons/image_resizer_processor_test/source.png');

  const icons = {
    IosIcon(size: 20, idiom: DarwinIdiom.iPhone, scale: 2),
    IosIcon(size: 29, idiom: DarwinIdiom.iPhone, scale: 1),
  };

  setUp(() {
    logger = TestUtils.quietLogger();
    flavorizr = TestUtils.parseFlavorizr('test_resources/pubspec');
  });

  test(
      'Test DarwinIconTargetProcessor queues a Contents.json processor and one resize processor per icon',
      () {
    final processor = _TestDarwinIconTargetProcessor(
      sourceFixture,
      flavorName: 'apple',
      iconSet: icons,
      appIconPath: 'AppIcon-%s.appiconset/%s',
      config: flavorizr,
      logger: logger,
    );

    // 1 Contents.json processor + 1 resize processor per icon.
    expect(processor.processors.length, icons.length + 1);
  });

  test(
      'Test DarwinIconTargetProcessor writes Contents.json and resized icon files',
      () async {
    await TestUtils.withTempDir((dir) async {
      final appIconPath = '${dir.path}/AppIcon-%s.appiconset/%s';

      final processor = _TestDarwinIconTargetProcessor(
        sourceFixture,
        flavorName: 'apple',
        iconSet: icons,
        appIconPath: appIconPath,
        config: flavorizr,
        logger: logger,
      );

      await processor.execute();

      final contentsFile =
          File('${dir.path}/AppIcon-apple.appiconset/Contents.json');
      expect(contentsFile.existsSync(), isTrue);

      final json = jsonDecode(contentsFile.readAsStringSync());
      expect(json['images'], hasLength(icons.length));

      for (final icon in icons) {
        expect(
          File('${dir.path}/AppIcon-apple.appiconset/${icon.fileName}')
              .existsSync(),
          isTrue,
        );
      }
    });
  });

}
