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

import 'package:flutter_flavorizr/src/engine/resource_key.dart';
import 'package:test/test.dart';

void main() {
  group('ResourceKey', () {
    test('is equal to a key with the same name and type', () {
      expect(const ResourceKey<int>('a'), const ResourceKey<int>('a'));
      expect(
        const ResourceKey<int>('a').hashCode,
        const ResourceKey<int>('a').hashCode,
      );
    });

    test('differs by name', () {
      expect(const ResourceKey<int>('a'), isNot(const ResourceKey<int>('b')));
    });

    test('differs by type', () {
      expect(
        const ResourceKey<int>('a'),
        isNot(const ResourceKey<String>('a')),
      );
    });
  });
}
