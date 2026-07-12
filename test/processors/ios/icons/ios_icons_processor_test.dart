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
import 'package:flutter_flavorizr/src/parser/parser.dart';
import 'package:flutter_flavorizr/src/processors/ios/icons/ios_icon_target_processor.dart';
import 'package:flutter_flavorizr/src/processors/ios/icons/ios_icons_processor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mason_logger/mason_logger.dart';

import '../../../test_utils.dart';

// NOTE: see ios_icon_target_processor_test.dart — IOSIconTargetProcessor
// (and therefore IOSIconsProcessor) writes to the hardcoded path
// `ios/Runner/Assets.xcassets/...`, so only constructor wiring is exercised
// here; `execute()` is intentionally not invoked.
void main() {
  late Flavorizr flavorizr;
  late Logger logger;

  setUp(() {
    logger = TestUtils.quietLogger();
  });

  test(
      'IOSIconsProcessor wires an IOSIconTargetProcessor for every flavor exposing an icon',
      () {
    flavorizr = TestUtils.parseFlavorizr('test_resources/pubspec');

    final processor = IOSIconsProcessor(config: flavorizr, logger: logger);

    // Neither `apple` nor `banana` in the shared fixture declares an icon,
    // so no target processors should be wired.
    expect(processor.processors, isEmpty);
  });

  test(
      'IOSIconsProcessor wires a target processor when the flavor (or app) declares an icon',
      () {
    const parser = Parser(
      pubspecPath: 'test_resources/ios/icons_processor_test/pubspec',
      flavorizrPath: 'test_resources/non_existent',
    );

    try {
      flavorizr = parser.parse();
    } catch (e) {
      fail(e.toString());
    }

    final processor = IOSIconsProcessor(config: flavorizr, logger: logger);

    expect(processor.processors.length, 1);
    expect(processor.processors, everyElement(isA<IOSIconTargetProcessor>()));
  });
}
