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
import 'package:flutter_flavorizr/src/processors/flutter/flutter_flavors_processor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mason_logger/mason_logger.dart';

import '../../test_utils.dart';

void main() {
  late Flavorizr flavorizr;
  late Logger logger;

  setUp(() {
    logger = TestUtils.quietLogger();
    flavorizr = TestUtils.parseFlavorizr('test_resources/pubspec');
  });

  test('Test FlutterFlavorsProcessor generates the Flavor enum with every flavor', () {
    final processor = FlutterFlavorsProcessor(config: flavorizr, logger: logger);

    final actual = processor.execute();

    expect(actual, contains('enum Flavor {'));
    for (final flavorName in flavorizr.flavors.keys) {
      expect(actual, contains('  ${flavorName.toLowerCase()},'));
    }
  });

  test('Test FlutterFlavorsProcessor generates the F class with title switch', () {
    final processor = FlutterFlavorsProcessor(config: flavorizr, logger: logger);

    final actual = processor.execute();

    expect(actual, contains('class F {'));
    expect(actual, contains('static late final Flavor appFlavor;'));
    expect(actual, contains('static String get name => appFlavor.name;'));
    expect(actual, contains('static String get title {'));

    flavorizr.flavors.forEach((name, flavor) {
      expect(actual, contains('case Flavor.${name.toLowerCase()}:'));
      expect(actual, contains("return '${flavor.app.escapedName}';"));
    });
  });

}
