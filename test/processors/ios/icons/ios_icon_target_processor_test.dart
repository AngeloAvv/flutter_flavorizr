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
import 'package:flutter_flavorizr/src/processors/ios/icons/ios_icon_target_processor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mason_logger/mason_logger.dart';

import '../../../test_utils.dart';

// NOTE: IOSIconTargetProcessor.execute() writes to the hardcoded,
// non-injectable path `ios/Runner/Assets.xcassets/...` (see
// `lib/src/utils/constants.dart` K.iOSAppIconPath), which is relative to the
// process working directory rather than to any test-controlled temp
// directory. Actually executing it here would write real files into this
// repository's own `ios/` folder, so this suite only exercises the
// constructor wiring (which is fully reachable and deterministic) and
// explicitly does not invoke `execute()`.
void main() {
  late Flavorizr flavorizr;
  late Logger logger;

  setUp(() {
    logger = TestUtils.quietLogger();
    flavorizr = TestUtils.parseFlavorizr('test_resources/pubspec');
  });

  test(
      'IOSIconTargetProcessor wires a Contents.json processor plus one resize processor per iOS icon entry',
      () {
    final processor = IOSIconTargetProcessor(
      'test_resources/commons/image_resizer_processor_test/source.png',
      'apple',
      config: flavorizr,
      logger: logger,
    );

    // 1 NewFileStringProcessor (Contents.json) + 19 IosIcon entries.
    expect(processor.processors.length, 20);
    expect(processor.processors.first, isA<NewFileStringProcessor>());

    final contentsProcessor =
        processor.processors.first as NewFileStringProcessor;
    expect(contentsProcessor.processor, isA<DarwinIconContentsProcessor>());
  });
}
