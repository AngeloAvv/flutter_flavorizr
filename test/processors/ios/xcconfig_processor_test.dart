/*
 * Copyright (c) 2023 Angelo Cassano
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
import 'package:flutter_flavorizr/src/parser/models/flavors/darwin/enums.dart';
import 'package:flutter_flavorizr/src/parser/parser.dart';
import 'package:flutter_flavorizr/src/processors/ios/xcconfig/ios_xcconfig_processor.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_utils.dart';

void main() {
  late Flavorizr flavorizr;

  test('Test IOXCConfigProcessor', () {
    Parser parser = Parser(
      pubspecPath:
          'test_resources/ios/xcconfig_processor_test/pubspec_without_variables.yaml',
      flavorizrPath: '',
    );
    try {
      flavorizr = parser.parse();
    } catch (e) {
      fail(e.toString());
    }

    String matcher = File(
            'test_resources/ios/xcconfig_processor_test/matcher_without_variables.xcconfig')
        .readAsStringSync();

    final flavorName = flavorizr.flavors.keys.last;
    final flavor = flavorizr.flavors[flavorName];

    IOSXCConfigProcessor processor = IOSXCConfigProcessor(
      flavorName,
      flavor!,
      Target.debug,
      config: flavorizr,
    );
    String actual = processor.execute();

    actual = TestUtils.stripEndOfLines(actual);
    matcher = TestUtils.stripEndOfLines(matcher);

    expect(actual, matcher);
  });

  test('Test IOXCConfigProcessor with variables', () {
    Parser parser = Parser(
      pubspecPath:
      'test_resources/ios/xcconfig_processor_test/pubspec_with_variables.yaml',
      flavorizrPath: '',
    );
    try {
      flavorizr = parser.parse();
    } catch (e) {
      fail(e.toString());
    }

    String matcher = File(
            'test_resources/ios/xcconfig_processor_test/matcher_with_variables.xcconfig')
        .readAsStringSync();

    final flavorName = flavorizr.flavors.keys.first;
    final flavor = flavorizr.flavors[flavorName];

    IOSXCConfigProcessor processor = IOSXCConfigProcessor(
      flavorName,
      flavor!,
      Target.debug,
      config: flavorizr,
    );
    String actual = processor.execute();

    actual = TestUtils.stripEndOfLines(actual);
    matcher = TestUtils.stripEndOfLines(matcher);

    expect(actual, matcher);
  });

  test('Test IOXCConfigProcessor with variables', () {
    Parser parser = Parser(
      pubspecPath:
          'test_resources/ios/xcconfig_processor_test/pubspec_with_variables.yaml',
      flavorizrPath: '',
    );

    try {
      flavorizr = parser.parse();
    } catch (e) {
      fail(e.toString());
    }

    String matcher = File(
            'test_resources/ios/xcconfig_processor_test/matcher_with_variables.xcconfig')
        .readAsStringSync();

    final flavorName = flavorizr.flavors.keys.first;
    final flavor = flavorizr.flavors[flavorName];

    IOSXCConfigProcessor processor = IOSXCConfigProcessor(
      flavorName,
      flavor!,
      Target.debug,
      config: flavorizr,
    );
    String actual = processor.execute();

    actual = TestUtils.stripEndOfLines(actual);
    matcher = TestUtils.stripEndOfLines(matcher);

    expect(actual, matcher);
  });

  test('Test IOXCConfigProcessor with variables and target', () {
    Parser parser = Parser(
      pubspecPath:
          'test_resources/ios/xcconfig_processor_test/pubspec_with_variables_and_target.yaml',
      flavorizrPath: '',
    );

    try {
      flavorizr = parser.parse();
    } catch (e) {
      fail(e.toString());
    }

    String matcher = File(
            'test_resources/ios/xcconfig_processor_test/matcher_with_variables_and_target.xcconfig')
        .readAsStringSync();

    final flavorName = flavorizr.flavors.keys.first;
    final flavor = flavorizr.flavors[flavorName];

    IOSXCConfigProcessor processor = IOSXCConfigProcessor(
      flavorName,
      flavor!,
      Target.release,
      config: flavorizr,
    );
    String actual = processor.execute();

    actual = TestUtils.stripEndOfLines(actual);
    matcher = TestUtils.stripEndOfLines(matcher);

    expect(actual, matcher);
  });
}
