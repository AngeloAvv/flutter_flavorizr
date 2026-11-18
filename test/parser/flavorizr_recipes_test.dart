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

import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:flutter_flavorizr/src/parser/models/pubspec.dart';
import 'package:flutter_test/flutter_test.dart';

String _config({String extra = '', String name = 'Apple'}) =>
    '''
app:
  android:
    flavorDimensions: "tier"
flavors:
  apple:
    app:
      name: "$name"
    android:
      applicationId: "com.example.apple"
  banana:
    app:
      name: "Banana"
    android:
      applicationId: "com.example.banana"
$extra''';

void main() {
  group('recipes', () {
    test('are absent by default', () {
      final config = FlavorizrConfig.parse(_config());

      expect(config.recipes, isNull);
      expect(config.defaultRecipe, isNull);
    });

    test('are read as lists of processor ids and recipes', () {
      final config = FlavorizrConfig.parse(
        _config(
          extra: '''
recipes:
  ci: [android, "ios:podfile"]
  nightly:
    - ci
    - firebase
''',
        ),
      );

      expect(config.recipes, {
        'ci': ['android', 'ios:podfile'],
        'nightly': ['ci', 'firebase'],
      });
      expect(config.defaultRecipe, isNull);
    });

    test('a `default` that is a name picks the recipe to run by default', () {
      final config = FlavorizrConfig.parse(
        _config(
          extra: '''
recipes:
  ci: [android]
  default: ci
''',
        ),
      );

      expect(config.recipes, {
        'ci': ['android'],
      });
      expect(config.defaultRecipe, 'ci');
    });

    test('a `default` that is a list is a recipe like any other', () {
      final config = FlavorizrConfig.parse(
        _config(extra: 'recipes:\n  default: [android]\n'),
      );

      expect(config.recipes, {
        'default': ['android'],
      });
      expect(config.defaultRecipe, isNull);
    });

    test('are read from the flavorizr section of a pubspec too', () {
      final pubspec = Pubspec.parse(
        'name: app\nflavorizr:\n  flavors:\n    a:\n      app:\n        name: A\n'
        '  recipes:\n    ci: [android]\n',
      );

      expect(pubspec.flavorizr.recipes, {
        'ci': ['android'],
      });
    });

    test('a recipe that is not a list of names is a format error', () {
      expect(
        () => FlavorizrConfig.parse(_config(extra: 'recipes:\n  ci: android\n')),
        throwsA(anything),
      );
    });
  });

  group('flavor fingerprints', () {
    test('there is one per flavor and it is a sha256', () {
      final config = FlavorizrConfig.parse(_config());

      expect(config.flavorFingerprints.keys, ['apple', 'banana']);
      expect(
        config.flavorFingerprints.values,
        everyElement(matches(RegExp(r'^sha256:[0-9a-f]{64}$'))),
      );
    });

    test('the same configuration always has the same fingerprints', () {
      expect(
        FlavorizrConfig.parse(_config()).flavorFingerprints,
        FlavorizrConfig.parse(_config()).flavorFingerprints,
      );
    });

    test('a change to a flavor changes its fingerprint and no other', () {
      final before = FlavorizrConfig.parse(_config()).flavorFingerprints;
      final after = FlavorizrConfig.parse(_config(name: 'Pear')).flavorFingerprints;

      expect(after['apple'], isNot(before['apple']));
      expect(after['banana'], before['banana']);
    });

    test('a change of the shared `app` section changes every flavor', () {
      final before = FlavorizrConfig.parse(_config()).flavorFingerprints;
      final after = FlavorizrConfig.parse(
        _config().replaceFirst('"tier"', '"kind"'),
      ).flavorFingerprints;

      expect(after['apple'], isNot(before['apple']));
      expect(after['banana'], isNot(before['banana']));
    });

    test('the order of the keys does not matter', () {
      final a = FlavorizrConfig.parse(
        'flavors:\n  x:\n    app:\n      name: X\n    android:\n'
        '      applicationId: a.b\n',
      );
      final b = FlavorizrConfig.parse(
        'flavors:\n  x:\n    android:\n      applicationId: a.b\n'
        '    app:\n      name: X\n',
      );

      expect(a.flavorFingerprints, b.flavorFingerprints);
    });
  });
}
