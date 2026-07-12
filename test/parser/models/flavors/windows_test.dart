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
import 'package:flutter_test/flutter_test.dart';

import '../../../test_utils.dart';

void main() {
  test(
    'Windows flavors default generateDummyAssets to true and icon to null when only `windows: {}` is set',
    () {
      final flavorizr = TestUtils.parseFlavorizr('test_resources/windows/pubspec');

      expect(flavorizr.windowsFlavorsAvailable, isTrue);
      expect(flavorizr.windowsFlavors.keys, containsAll(['apple', 'banana']));

      final apple = flavorizr.windowsFlavors['apple']!.windows!;
      expect(apple.generateDummyAssets, isTrue);
      expect(apple.icon, isNull);
    },
  );

  test(
    'Windows flavors are not available when no flavor configures the `windows` key',
    () {
      final flavorizr = TestUtils.parseFlavorizr('test_resources/pubspec');

      expect(flavorizr.windowsFlavorsAvailable, isFalse);
      expect(flavorizr.windowsFlavors, isEmpty);
    },
  );

  test(
    'Windows.fromJson honors an explicit icon and generateDummyAssets override',
    () {
      final flavorizr = Flavorizr.parse('''
flavors:
  apple:
    app:
      name: "Apple App"
    windows:
      icon: "assets/apple_icon.png"
      generateDummyAssets: false
''');

      final apple = flavorizr.windowsFlavors['apple']!.windows!;
      expect(apple.icon, "assets/apple_icon.png");
      expect(apple.generateDummyAssets, isFalse);
    },
  );
}
