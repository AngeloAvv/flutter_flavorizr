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
import 'package:test/test.dart';

const _yaml = '''
badge: true
launchScreen: true
icon: "assets/icon.png"
app:
  android:
    flavorDimensions: "type"
ide:
  - idea
recipes:
  default:
    - android
flavors:
  apple:
    app:
      name: "Apple"
    android:
      applicationId: "com.example.apple"
    ios:
      bundleId: "com.example.apple"
''';

void main() {
  group('FlavorizrConfig.withFlavors', () {
    final config = FlavorizrConfig.parse(_yaml);
    final other = FlavorizrConfig.parse(
      _yaml.replaceAll('apple', 'banana').replaceAll('Apple', 'Banana'),
    ).flavors;
    final copy = config.withFlavors(other);

    test('has the flavors it is given', () {
      expect(copy.flavors.keys, ['banana']);
      expect(copy.androidFlavors.keys, ['banana']);
    });

    test('keeps every other setting of the configuration', () {
      expect(copy.badge, isTrue);
      expect(copy.icon, 'assets/icon.png');
      expect(copy.launchScreen, isTrue);
      expect(copy.app, same(config.app));
      expect(copy.ide, config.ide);
      expect(copy.recipes, config.recipes);
      expect(copy.defaultRecipe, config.defaultRecipe);
      expect(copy.flavorFingerprints, config.flavorFingerprints);
      expect(copy.deprecations, config.deprecations);
    });

    test('resolves the launch screen of a flavor from the root settings', () {
      expect(copy.launchScreenOf('banana'), isTrue);
      expect(copy.launchScreenFlavors.keys, ['banana']);
    });

    test('resolves the badge of a flavor from the root settings', () {
      expect(copy.badgeOf('banana'), isNotNull);
    });
  });
}
