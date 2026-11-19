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

import 'package:flutter_flavorizr/src/badge/badge_label.dart';
import 'package:test/test.dart';

void main() {
  group('badgeLabel', () {
    test('is the flavor name in upper case when there is no label', () {
      expect(badgeLabel('staging'), 'STAGING');
      expect(badgeLabel('dev'), 'DEV');
      expect(badgeLabel('qaTwo'), 'QATWO');
    });

    test('is the label as it is, when there is one', () {
      expect(badgeLabel('staging', 'Beta'), 'Beta');
    });

    test('keeps 8 characters', () {
      expect(badgeLabel('abcdefgh'), 'ABCDEFGH');
      expect(badgeLabel('x', 'abcdefgh'), 'abcdefgh');
    });

    test('truncates more than 8 characters to 7 and an ellipsis', () {
      expect(badgeLabel('production'), 'PRODUCT…');
      expect(badgeLabel('abcdefghi'), 'ABCDEFG…');
      expect(badgeLabel('x', 'Pre-production'), 'Pre-pro…');
      expect(badgeLabel('x', 'Pre-production'), hasLength(8));
    });

    test('counts characters, not UTF-16 units', () {
      expect(badgeLabel('x', '😀😀😀😀😀😀😀😀'), '😀😀😀😀😀😀😀😀');
      expect(badgeLabel('x', '😀😀😀😀😀😀😀😀😀'), '😀😀😀😀😀😀😀…');
    });
  });
}
