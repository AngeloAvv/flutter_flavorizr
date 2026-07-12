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

import 'package:flutter_flavorizr/src/exception/missing_required_fields_exception.dart';
import 'package:flutter_flavorizr/src/exception/null_fields_exception.dart';
import 'package:flutter_flavorizr/src/parser/parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Test Flavorizr loaded from a dedicated .yml (not .yaml) file', () {
    const parser = Parser(
      pubspecPath: 'test_resources/non_existent',
      flavorizrPath:
          'test_resources/parser/parser_test/flavorizr_yml/flavorizr',
    );

    final flavorizr = parser.parse();

    expect(flavorizr.flavors.containsKey('apple'), isTrue);
  });

  test(
    'Test dedicated flavorizr file takes precedence over pubspec when both exist',
    () {
      const parser = Parser(
        pubspecPath: 'test_resources/parser/parser_test/precedence/pubspec',
        flavorizrPath: 'test_resources/parser/parser_test/precedence/flavorizr',
      );

      final flavorizr = parser.parse();

      expect(flavorizr.flavors.containsKey('fromFlavorizrFile'), isTrue);
      expect(flavorizr.flavors.containsKey('fromPubspecFile'), isFalse);
    },
  );

  // The `Flavorizr.flavors` map and `Pubspec.flavorizr` keys are `required`
  // but *not* `disallowNullValue`, so a missing/null top-level `flavors` key
  // is not usable to trigger MissingRequiredFieldsException/NullFieldsException
  // (see nested Flavor test below, whose `app` field is annotated with both
  // `required: true` and `disallowNullValue: true` in flavor.g.dart).
  test(
    'Test missing required "app" key on a flavor throws MissingRequiredFieldsException',
    () {
      const parser = Parser(
        pubspecPath: 'test_resources/non_existent',
        flavorizrPath:
            'test_resources/parser/parser_test/missing_required/flavorizr',
      );

      try {
        parser.parse();
        fail('Should have thrown MissingRequiredFieldsException');
      } catch (e) {
        expect(e, isA<MissingRequiredFieldsException>());
        expect((e as MissingRequiredFieldsException).fields, contains('app'));
        expect(e.toString(), contains('app'));
      }
    },
  );

  test(
    'Test explicit null value for required "app" key on a flavor throws NullFieldsException',
    () {
      const parser = Parser(
        pubspecPath: 'test_resources/non_existent',
        flavorizrPath:
            'test_resources/parser/parser_test/null_required/flavorizr',
      );

      try {
        parser.parse();
        fail('Should have thrown NullFieldsException');
      } catch (e) {
        expect(e, isA<NullFieldsException>());
        expect((e as NullFieldsException).fields, contains('app'));
        expect(e.toString(), contains('app'));
      }
    },
  );
}
