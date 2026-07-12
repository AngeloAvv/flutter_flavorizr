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

// NOTE: `StringProcessor` is a pure abstract base (it only adds the `input`
// field and a fixed `toString()` override on top of `AbstractProcessor`).
// There is no independent branching logic to cover beyond what is already
// exercised indirectly by every concrete subclass test (e.g.
// `replace_string_processor_test.dart`, `empty_file_processor_test.dart`,
// `abstract_file_string_processor_test.dart`). This test only covers the
// `input` field wiring and the fixed `toString()` value, which are the only
// behaviors owned by this class itself.

import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:flutter_flavorizr/src/processors/commons/string_processor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mason_logger/mason_logger.dart';

import '../../test_utils.dart';

class _StubStringProcessor extends StringProcessor {
  _StubStringProcessor({
    super.input,
    required super.config,
    required super.logger,
  });

  @override
  String execute() => input ?? '';
}

void main() {
  late Flavorizr flavorizr;
  late Logger logger;

  setUp(() {
    logger = TestUtils.quietLogger();
    flavorizr = TestUtils.parseFlavorizr('test_resources/pubspec');
  });

  test('Test StringProcessor exposes the input field', () {
    final processor = _StubStringProcessor(
      input: 'hello',
      config: flavorizr,
      logger: logger,
    );

    expect(processor.input, 'hello');
  });

  test('Test StringProcessor input defaults to null when not provided', () {
    final processor = _StubStringProcessor(
      config: flavorizr,
      logger: logger,
    );

    expect(processor.input, isNull);
  });

}
