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
import 'package:json_annotation/json_annotation.dart';

import '../../../test_utils.dart';

void main() {
  test(
    'Linux flavors are collected into Flavorizr.linuxFlavors with their applicationId',
    () {
      final flavorizr = TestUtils.parseFlavorizr('test_resources/linux/pubspec');

      expect(flavorizr.linuxFlavorsAvailable, isTrue);
      expect(flavorizr.linuxFlavors.keys, containsAll(['apple', 'banana']));

      final apple = flavorizr.linuxFlavors['apple']!.linux!;
      expect(apple.applicationId, "com.example.apple");
    },
  );

  test(
    'Linux flavors are not available when no flavor configures the `linux` key',
    () {
      final flavorizr = TestUtils.parseFlavorizr('test_resources/pubspec');

      expect(flavorizr.linuxFlavorsAvailable, isFalse);
      expect(flavorizr.linuxFlavors, isEmpty);
    },
  );

  test(
    'Linux.fromJson throws when applicationId is missing',
    () {
      expect(
        () => Flavorizr.parse('''
flavors:
  apple:
    app:
      name: "Apple App"
    linux: {}
'''),
        throwsA(isA<MissingRequiredKeysException>()),
      );
    },
  );
}
