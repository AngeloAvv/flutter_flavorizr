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

import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:flutter_flavorizr/src/parser/models/flavors/android/adaptive_icon.dart';
import 'package:flutter_flavorizr/src/processors/android/icons/android_generate_iclauncher_xml_processor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mason_logger/mason_logger.dart';

import '../../../test_utils.dart';

void main() {
  late Flavorizr flavorizr;
  late Logger logger;

  setUp(() {
    logger = TestUtils.quietLogger();
    flavorizr = TestUtils.parseFlavorizr('test_resources/pubspec');
  });

  test(
      'Test AndroidGenerateIclauncherXmlProcessor without monochrome generates background/foreground only',
      () {
    const adaptiveIcon = AdaptiveIcon(
      foreground: 'foreground.png',
      background: 'background.png',
    );

    final processor = AndroidGenerateIclauncherXmlProcessor(
      adaptiveIcon: adaptiveIcon,
      config: flavorizr,
      logger: logger,
    );

    final actual = processor.execute();

    expect(actual, contains('<?xml version="1.0" encoding="utf-8"?>'));
    expect(actual, contains('<adaptive-icon'));
    expect(
      actual,
      contains(
          '<background android:drawable="@drawable/ic_launcher_background" />'),
    );
    expect(
      actual,
      contains(
          '<foreground android:drawable="@drawable/ic_launcher_foreground" />'),
    );
    expect(actual, isNot(contains('monochrome')));
    expect(actual, contains('</adaptive-icon>'));
  });

  test(
      'Test AndroidGenerateIclauncherXmlProcessor with monochrome adds monochrome entry',
      () {
    const adaptiveIcon = AdaptiveIcon(
      foreground: 'foreground.png',
      background: 'background.png',
      monochrome: 'monochrome.png',
    );

    final processor = AndroidGenerateIclauncherXmlProcessor(
      adaptiveIcon: adaptiveIcon,
      config: flavorizr,
      logger: logger,
    );

    final actual = processor.execute();

    expect(
      actual,
      contains(
          '<monochrome android:drawable="@drawable/ic_launcher_monochrome" />'),
    );
  });

}
