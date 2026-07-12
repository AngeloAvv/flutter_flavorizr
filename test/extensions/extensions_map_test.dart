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

import 'package:flutter_flavorizr/src/extensions/extensions_map.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MapExtensions.where', () {
    test('filters entries based on the predicate', () {
      final map = {'a': 1, 'b': 2, 'c': 3};

      final result = map.where((key, value) => value.isEven);

      expect(result, {'b': 2});
    });

    test('returns an empty map when no entries satisfy the predicate', () {
      final map = {'a': 1, 'b': 3, 'c': 5};

      final result = map.where((key, value) => value.isEven);

      expect(result, isEmpty);
    });

    test('returns an empty map when the source map is empty', () {
      final map = <String, int>{};

      final result = map.where((key, value) => true);

      expect(result, isEmpty);
    });

    test('excludes entries whose value is null', () {
      final map = <String, int?>{'a': 1, 'b': null};

      final result = map.where((key, value) => true);

      expect(result, {'a': 1});
    });

    test('predicate receives both key and value', () {
      final map = {'x': 10, 'y': 20};

      final result = map.where((key, value) => key == 'y' && value == 20);

      expect(result, {'y': 20});
    });

    test('does not mutate the original map', () {
      final map = {'a': 1, 'b': 2};

      map.where((key, value) => value == 1);

      expect(map, {'a': 1, 'b': 2});
    });
  });
}
