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

import 'package:flutter_flavorizr/src/processors/processor.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_utils.dart';

void main() {
  test(
    'Processor.resolveInstructions drops linux:*/windows:* instructions when no flavor configures those platforms',
    () {
      final flavorizr = TestUtils.parseFlavorizr('test_resources/pubspec');
      final processor = Processor(flavorizr, logger: TestUtils.quietLogger());

      final instructions = processor.resolveInstructions();

      expect(instructions.any((i) => i.startsWith('linux')), isFalse);
      expect(instructions.any((i) => i.startsWith('windows')), isFalse);
      expect(instructions.any((i) => i.startsWith('android')), isTrue);
      expect(instructions.any((i) => i.startsWith('ios')), isTrue);
    },
  );

  test(
    'Processor.resolveInstructions keeps linux:* instructions when a flavor configures `linux`',
    () {
      final flavorizr = TestUtils.parseFlavorizr('test_resources/linux/pubspec');
      final processor = Processor(flavorizr, logger: TestUtils.quietLogger());

      final instructions = processor.resolveInstructions();

      expect(instructions, contains('linux:cmake'));
      expect(instructions, contains('linux:runnerCmake'));
      expect(instructions, contains('linux:myApplication'));
    },
  );

  test(
    'Processor.resolveInstructions keeps windows:* instructions when a flavor configures `windows`',
    () {
      final flavorizr = TestUtils.parseFlavorizr('test_resources/windows/pubspec');
      final processor = Processor(flavorizr, logger: TestUtils.quietLogger());

      final instructions = processor.resolveInstructions();

      expect(instructions, contains('windows:cmake'));
      expect(instructions, contains('windows:mainCppTemplate'));
      expect(instructions, contains('windows:runnerRcTemplate'));
      expect(instructions, contains('windows:dummyAssets'));
      expect(instructions, contains('windows:icons'));
    },
  );

  test(
    'Processor.resolveInstructions respects an explicit `instructions` override in the config',
    () {
      final flavorizr = TestUtils.parseFlavorizr('test_resources/windows/pubspec')
        ..instructions = ['windows:cmake'];
      final processor = Processor(flavorizr, logger: TestUtils.quietLogger());

      expect(processor.resolveInstructions(), ['windows:cmake']);
    },
  );
}
