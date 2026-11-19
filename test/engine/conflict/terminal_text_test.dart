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

import 'package:flutter_flavorizr/src/engine/conflict/terminal_text.dart';
import 'package:test/test.dart';

void main() {
  test('plain text, newlines and tabs are untouched', () {
    expect(
      printable('lib/a.dart\n\tline "é" 日本\n'),
      'lib/a.dart\n\tline "é" 日本\n',
    );
  });

  test('the escape character is made visible', () {
    expect(printable('a\x1B[31mb'), 'a␛[31mb');
  });

  test('other control characters are made visible', () {
    expect(printable('a\rb\x08c\x07d\x7Fe'), 'a␍b␈c␇d␡e');
  });

  test('C1 control characters, which some terminals obey, are replaced', () {
    expect(printable('a\u009Bb\u0085c'), 'a\u{FFFD}b\u{FFFD}c');
  });

  group('printablePath', () {
    test('a path on one line is untouched', () {
      expect(printablePath('lib/src/a b.dart'), 'lib/src/a b.dart');
    });

    test('newlines and tabs are made visible, so a path is one line', () {
      expect(
        printablePath('lib/a.dart\n  - lib/b.dart\t!'),
        'lib/a.dart␊  - lib/b.dart␉!',
      );
    });

    test('control characters are made visible as in file content', () {
      expect(printablePath('a\x1B[2J\r\u009Bb'), 'a␛[2J␍\u{FFFD}b');
    });
  });

  test('a path cannot hide the end of its line', () {
    expect(printable('lib/a.dart\r  OK'), isNot(contains('\r')));
  });
}
