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

import 'dart:io';

import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:flutter_flavorizr/src/parser/parser.dart';
import 'package:flutter_flavorizr/src/processors/darwin/podfile_processor.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_utils.dart';

void main() {
  late Flavorizr flavorizr;

  setUp(() {
    Parser parser = const Parser(
      pubspecPath: 'test_resources/pubspec.yaml',
      flavorizrPath: '',
    );
    try {
      flavorizr = parser.parse();
    } catch (e) {
      fail(e.toString());
    }
  });

  tearDown(() {});

  test('Test original PodfileProcessor', () {
    String content = File('test_resources/darwin/podfile_test/PodfileOriginal')
        .readAsStringSync();
    String matcher = File('test_resources/darwin/podfile_test/PodfileExpected')
        .readAsStringSync();

    PodfileProcessor processor = PodfileProcessor(
      config: flavorizr,
      flavors: flavorizr.iosFlavors.keys.toList(growable: false),
      input: content,
    );
    String actual = processor.execute();

    actual = TestUtils.stripEndOfLines(actual);
    matcher = TestUtils.stripEndOfLines(matcher);

    expect(actual, matcher);
  });

  test('Test malformed PodfileProcessor', () {
    PodfileProcessor processor = PodfileProcessor(
      config: flavorizr,
      flavors: flavorizr.iosFlavors.keys.toList(growable: false),
      input: '',
    );
    expect(() => processor.execute(), throwsException);
  });
}