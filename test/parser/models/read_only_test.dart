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

import 'package:flutter_flavorizr/experimental.dart';
import 'package:flutter_test/flutter_test.dart';

const _yaml = '''
app:
  android:
    resValues:
      a: {type: string, value: x}
  ios:
    buildSettings:
      KEY: [one, two]
flavors:
  apple:
    app:
      name: Apple
    android:
      applicationId: com.example.apple
      customConfig:
        nested: {list: [1, 2]}
    ios:
      bundleId: com.example.apple
      includes:
        - value: a.xcconfig
      variables:
        V: {value: v}
    macos:
      bundleId: com.example.apple
ide: [idea]
recipes:
  ci: [android:icons]
  default: ci
''';

void main() {
  group('the configuration is read-only', () {
    final config = FlavorizrConfig.parse(_yaml);

    test('in what a processor reads first', () {
      expect(
        () => config.flavors['b'] = config.flavors['apple']!,
        throwsUnsupportedError,
      );
      expect(() => config.flavors.remove('apple'), throwsUnsupportedError);
      expect(() => config.ide!.add(IDE.vscode), throwsUnsupportedError);
      expect(() => config.recipes!['x'] = [], throwsUnsupportedError);
      expect(() => config.recipes!['ci']!.add('x'), throwsUnsupportedError);
      expect(
        () => config.flavorFingerprints['x'] = 'y',
        throwsUnsupportedError,
      );
    });

    test('in what it tells from the flavors', () {
      for (final flavors in [
        config.androidFlavors,
        config.iosFlavors,
        config.macosFlavors,
        config.linuxFlavors,
        config.windowsFlavors,
        config.androidFirebaseFlavors,
        config.androidAGConnectFlavors,
        config.iosFirebaseFlavors,
        config.macosFirebaseFlavors,
      ]) {
        expect(() => flavors.clear(), throwsUnsupportedError);
      }
    });

    test('in the flavors', () {
      final flavor = config.flavors['apple']!;

      expect(
        () => flavor.android!.customConfig['x'] = 1,
        throwsUnsupportedError,
      );
      expect(
        () => (flavor.android!.customConfig['nested'] as Map)['x'] = 1,
        throwsUnsupportedError,
      );
      expect(
        () => ((flavor.android!.customConfig['nested'] as Map)['list'] as List)
            .add(3),
        throwsUnsupportedError,
      );
      expect(
        () => flavor.ios!.includes.add(flavor.ios!.includes.first),
        throwsUnsupportedError,
      );
      expect(() => flavor.ios!.variables.clear(), throwsUnsupportedError);
      expect(() => flavor.ios!.buildSettings['x'] = 1, throwsUnsupportedError);
      expect(
        flavor.ios!.buildSettings['PRODUCT_BUNDLE_IDENTIFIER'],
        'com.example.apple',
      );
    });

    test('in what every flavor starts from', () {
      expect(
        () => config.app!.android!.resValues.clear(),
        throwsUnsupportedError,
      );
      expect(
        () => config.app!.ios!.buildSettings['x'] = 1,
        throwsUnsupportedError,
      );
      expect(
        () => (config.app!.ios!.buildSettings['KEY'] as List).add('three'),
        throwsUnsupportedError,
      );
    });

    test('and the defaults it starts from are not shared', () {
      FlavorizrConfig.parse(_yaml);

      expect(
        BuildSettingsMixin.iosDefaultBuildSettings.containsKey('KEY'),
        isFalse,
      );
      expect(
        FlavorizrConfig.parse(
          'flavors: {a: {app: {name: A}}}\napp: {ios: {}}\n',
        ).app!.ios!.buildSettings.containsKey('KEY'),
        isFalse,
      );
    });

    test('reads what the document says all the same', () {
      expect(config.flavors.keys, ['apple']);
      expect(config.ide, [IDE.idea]);
      expect(config.recipes, {
        'ci': ['android:icons'],
      });
      expect(config.defaultRecipe, 'ci');
      expect(config.flavorFingerprints.keys, ['apple']);
    });
  });
}
