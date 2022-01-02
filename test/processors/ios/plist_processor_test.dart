/*
 * Copyright (c) 2022 MyLittleSuite
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

import 'package:flutter_flavorizr/parser/models/pubspec.dart';
import 'package:flutter_flavorizr/parser/parser.dart';
import 'package:flutter_flavorizr/processors/ios/ios_plist_processor.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_utils.dart';

void main() {
  Pubspec? pubspec;

  setUp(() {
    Parser parser = Parser(file: 'test_resources/pubspec.yaml');
    try {
      pubspec = parser.parse();
    } catch (e) {
      fail(e.toString());
    }
  });

  tearDown(() {});

  test('Test iOSPListProcessor', () {
    String content = File('test_resources/ios/plist_processor_test/Info.plist')
        .readAsStringSync();
    String matcher =
        File('test_resources/ios/plist_processor_test/Matcher.plist')
            .readAsStringSync();

    IOSPListProcessor processor = IOSPListProcessor(
      input: content,
      config: pubspec!.flavorizr,
    );
    String actual = processor.execute();

    actual = TestUtils.stripEndOfLines(actual);
    matcher = TestUtils.stripEndOfLines(matcher);

    expect(actual, matcher);
  });

  test('Test malformed iOSPListProcessor', () {
    String content =
        File('test_resources/ios/plist_processor_test/Malformed.plist')
            .readAsStringSync();

    IOSPListProcessor processor = IOSPListProcessor(
      input: content,
      config: pubspec!.flavorizr,
    );
    expect(() => processor.execute(), throwsException);
  });
}
