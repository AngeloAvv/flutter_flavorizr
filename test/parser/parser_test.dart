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

import 'package:flutter_flavorizr/src/exception/invalid_configuration_exception.dart';
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
        expect(e.path, 'flavors.apple');
        expect(e.toString(), contains('app'));
        expect(e.toString(), contains('flavorizr.yaml:3:5'));
        expect(e.toString(), contains('`flavors.apple`'));
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
        expect(e.path, 'flavors.apple');
        expect(e.toString(), contains('app'));
      }
    },
  );

  group('a key that is not known', () {
    UnknownFieldsException unknown(String dir, {String file = 'flavorizr'}) {
      final parser = Parser(
        pubspecPath: 'test_resources/parser/parser_test/$dir/pubspec',
        flavorizrPath: 'test_resources/parser/parser_test/$dir/$file',
      );

      try {
        parser.parse();
      } on UnknownFieldsException catch (e) {
        return e;
      }

      fail('Should have thrown UnknownFieldsException');
    }

    test('names the key, where it is and the one that was meant', () {
      // A user wrote `bundle_id` for `bundleId` (#437).
      final error = unknown('unknown_key');

      expect(error.fields, ['bundle_id']);
      expect(error.path, 'flavors.apple.ios');
      expect(error.suggestions, {'bundle_id': 'bundleId'});
      expect(error.location, 'flavorizr.yaml:6:7');
      expect(
        error.toString(),
        'flavorizr.yaml:6:7: Unknown key `bundle_id` in `flavors.apple.ios`: '
        'did you mean `bundleId` instead of `bundle_id`?',
      );
    });

    test('is found in a map at any depth, every one of them', () {
      // `app.ios.buildSettigns` comes first in the file.
      final error = unknown('unknown_nested');

      expect(error.fields, ['buildSettigns']);
      expect(error.path, 'app.ios');
      expect(error.suggestions, {'buildSettigns': 'buildSettings'});
    });

    test('is found in a flavor too, with more than one in a map', () {
      final error = unknown('unknown_nested', file: 'flavorizr_fixed');

      expect(error.fields, ['nme', 'other']);
      expect(error.path, 'flavors.apple.app');
      expect(error.suggestions, {'nme': 'name'});
      expect(
        error.toString(),
        contains('did you mean `name` instead of `nme`?'),
      );
    });

    test('is found in the flavorizr section of the pubspec, whatever else '
        'the pubspec has', () {
      final error = unknown('unknown_pubspec', file: 'non_existent');

      expect(error.fields, ['applicationID']);
      expect(error.path, 'flavorizr.flavors.apple.android');
      expect(error.suggestions, {'applicationID': 'applicationId'});
      // The typo is the second key of its map: its own line, not the map's.
      expect(error.location, 'pubspec.yaml:12:9');
    });

    test(
      'lists the known keys too when some of the keys have no suggestion',
      () {
        final error = unknown('unknown_nested', file: 'flavorizr_fixed');

        expect(error.fields, ['nme', 'other']);
        expect(
          error.toString(),
          contains('did you mean `name` instead of `nme`?'),
        );
        expect(error.toString(), contains('The known keys are:'));
      },
    );

    test('lists the known keys when none is close', () {
      final error = unknown('unknown_far');

      expect(error.suggestions, isEmpty);
      expect(error.path, 'flavors.apple.app');
      expect(error.toString(), contains('The known keys are:'));
      expect(error.toString(), contains('name'));
    });
  });

  group('a configuration that is not usable', () {
    InvalidConfigurationException invalid(String dir) {
      final parser = Parser(
        pubspecPath: 'test_resources/non_existent',
        flavorizrPath: 'test_resources/parser/parser_test/$dir/flavorizr',
      );

      try {
        parser.parse();
      } on InvalidConfigurationException catch (e) {
        return e;
      }

      fail('Should have thrown InvalidConfigurationException');
    }

    test('still takes a number for the name of a recipe', () {
      final flavorizr = const Parser(
        pubspecPath: 'test_resources/non_existent',
        flavorizrPath:
            'test_resources/parser/parser_test/numeric_recipe/flavorizr',
      ).parse();

      expect(flavorizr.recipes?.keys, ['42']);
    });

    test('takes a number for the name of a recipe in a pubspec too', () {
      final flavorizr = const Parser(
        pubspecPath:
            'test_resources/parser/parser_test/numeric_recipe_pubspec/pubspec',
        flavorizrPath: 'test_resources/non_existent',
      ).parse();

      expect(flavorizr.recipes?.keys, ['42']);
    });

    test('names the map where an aliased map is used, not where it is '
        'defined', () {
      try {
        const Parser(
          pubspecPath: 'test_resources/parser/parser_test/aliased_map/pubspec',
          flavorizrPath: 'test_resources/non_existent',
        ).parse();
        fail('Should have thrown InvalidConfigurationException');
      } on InvalidConfigurationException catch (e) {
        expect(
          e.toString(),
          contains(
            'of `flavorizr.flavors.apple.ios.buildSettings` must be text',
          ),
        );
      }
    });

    test('names the map of a key that is itself a map', () {
      expect(
        invalid('map_key').toString(),
        contains('of `flavors.apple.ios.buildSettings` must be text'),
      );
    });

    test('does not read the sections of a pubspec that are not its own', () {
      final flavorizr = const Parser(
        pubspecPath: 'test_resources/parser/parser_test/unrelated_keys/pubspec',
        flavorizrPath: 'test_resources/non_existent',
      ).parse();

      expect(flavorizr.flavors.keys, ['apple']);
    });

    test('says where a YAML syntax error is', () {
      expect(
        invalid('syntax_error').toString(),
        allOf(contains('flavorizr.yaml'), contains('line 3')),
      );
    });

    test('is refused when it is not a map', () {
      expect(
        invalid('not_a_map').toString(),
        'flavorizr.yaml:1:1: The configuration must be a map of keys',
      );
    });

    test('names a key that is not text and where it is', () {
      final error = invalid('non_string_key');

      expect(
        error.toString(),
        'flavorizr.yaml:8:9: The key `42` of `flavors.apple.ios.buildSettings` '
        'must be text: quote it to make it so',
      );
    });

    test('says which map the missing fields of the adaptive icon are from', () {
      final parser = Parser(
        pubspecPath: 'test_resources/non_existent',
        flavorizrPath:
            'test_resources/parser/parser_test/adaptive_icon_missing/flavorizr',
      );

      try {
        parser.parse();
        fail('Should have thrown MissingRequiredFieldsException');
      } on MissingRequiredFieldsException catch (e) {
        expect(e.fields, ['foreground']);
        expect(e.path, 'flavors.apple.android.adaptiveIcon');
      }
    });
  });
}
