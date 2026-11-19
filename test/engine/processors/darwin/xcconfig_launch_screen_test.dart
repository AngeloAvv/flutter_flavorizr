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

import 'package:flutter_flavorizr/src/engine/processors/darwin/xcconfig_sources.dart';
import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:flutter_flavorizr/src/parser/models/flavors/darwin/enums.dart';
import 'package:test/test.dart';

String _config({String root = '', Map<String, String> flavors = const {}}) => [
  root,
  'flavors:',
  for (final MapEntry(:key, :value) in flavors.entries) ...[
    '  $key:',
    '    app:',
    '      name: $key',
    '    ios:',
    '      bundleId: com.example.$key',
    '      variables:',
    '        TEAM:',
    '          value: abc',
    '    macos:',
    '      bundleId: com.example.$key',
    if (value.isNotEmpty) value,
  ],
].join('\n');

String _ios(FlavorizrConfig config, String flavor) =>
    iosXcconfigSource(config, flavor, config.flavors[flavor]!, Target.release);

void main() {
  group('LAUNCH_SCREEN_NAME in the xcconfig of iOS', () {
    test('is not defined when no flavor has a launch screen', () {
      final config = FlavorizrConfig.parse(_config(flavors: {'dev': ''}));

      expect(_ios(config, 'dev'), isNot(contains('LAUNCH_SCREEN_NAME')));
    });

    test('is the storyboard of the flavor, which has a launch screen', () {
      final config = FlavorizrConfig.parse(
        _config(flavors: {'dev': '    launchScreen: true'}),
      );

      expect(
        _ios(config, 'dev'),
        contains('\nLAUNCH_SCREEN_NAME=devLaunchScreen\n'),
      );
    });

    test('comes before the variables of the flavor, which may override it', () {
      final config = FlavorizrConfig.parse(
        _config(root: 'launchScreen: true', flavors: {'dev': ''}),
      );
      final lines = _ios(config, 'dev').split('\n');

      expect(
        lines.indexOf('LAUNCH_SCREEN_NAME=devLaunchScreen'),
        lessThan(lines.indexOf('TEAM=abc')),
      );
    });

    test('is the launch screen of the project in a flavor that has none, '
        'when another flavor has one', () {
      final config = FlavorizrConfig.parse(
        _config(flavors: {'dev': '    launchScreen: true', 'prod': ''}),
      );

      expect(
        _ios(config, 'prod'),
        contains('\nLAUNCH_SCREEN_NAME=LaunchScreen\n'),
      );
      expect(
        _ios(config, 'dev'),
        contains('\nLAUNCH_SCREEN_NAME=devLaunchScreen\n'),
      );
    });

    test('is a property of each build mode of the flavor', () {
      final config = FlavorizrConfig.parse(
        _config(root: 'launchScreen: true', flavors: {'dev': ''}),
      );

      for (final target in Target.values) {
        expect(
          iosXcconfigSource(config, 'dev', config.flavors['dev']!, target),
          contains('LAUNCH_SCREEN_NAME=devLaunchScreen'),
          reason: target.name,
        );
      }
    });

    test('is not in the xcconfig of macOS', () {
      final config = FlavorizrConfig.parse(
        _config(root: 'launchScreen: true', flavors: {'dev': ''}),
      );
      final flavor = config.flavors['dev']!;

      expect(
        macosConfigsXcconfigSource(config, 'dev', flavor, Target.debug),
        isNot(contains('LAUNCH_SCREEN_NAME')),
      );
      expect(
        macosFlutterXcconfigSource(config, 'dev', flavor, Target.debug),
        isNot(contains('LAUNCH_SCREEN_NAME')),
      );
    });
  });
}
