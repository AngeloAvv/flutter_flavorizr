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
import 'package:flutter_flavorizr/src/processors/commons/new_file_string_processor.dart';
import 'package:flutter_flavorizr/src/processors/darwin/icons/darwin_icon_contents_processor.dart';
import 'package:flutter_flavorizr/src/processors/macos/icons/macos_icon_target_processor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mason_logger/mason_logger.dart';

import '../../../test_utils.dart';

// NOTE: MacOSIconTargetProcessor.execute() writes to the hardcoded,
// non-injectable path `macos/Runner/Assets.xcassets/...` (see
// `lib/src/utils/constants.dart` K.macOSAppIconPath), so only constructor
// wiring is exercised here; `execute()` is intentionally not invoked to
// avoid writing into this repository's own `macos/` folder.
void main() {
  late Flavorizr flavorizr;
  late Logger logger;

  setUp(() {
    logger = TestUtils.quietLogger();
    flavorizr = TestUtils.parseFlavorizr(
      'test_resources/macos/icons_processor_test/pubspec',
    );
  });

  test(
      'MacOSIconTargetProcessor wires a Contents.json processor plus one resize processor per macOS icon entry',
      () {
    final processor = MacOSIconTargetProcessor(
      'test_resources/commons/image_resizer_processor_test/source.png',
      'apple',
      config: flavorizr,
      logger: logger,
    );

    // 1 NewFileStringProcessor (Contents.json) + 10 MacosIcon entries.
    expect(processor.processors.length, 11);
    expect(processor.processors.first, isA<NewFileStringProcessor>());

    final contentsProcessor =
        processor.processors.first as NewFileStringProcessor;
    expect(contentsProcessor.processor, isA<DarwinIconContentsProcessor>());
  });
}
