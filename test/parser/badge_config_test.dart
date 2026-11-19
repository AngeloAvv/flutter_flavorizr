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

import 'package:flutter_flavorizr/src/badge/badge_color.dart';
import 'package:flutter_flavorizr/src/badge/badge_palette.dart';
import 'package:flutter_flavorizr/src/exception/invalid_configuration_exception.dart';
import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:flutter_flavorizr/src/parser/parser.dart';
import 'package:test/test.dart';

String _config({String root = '', Map<String, String> flavors = const {}}) => [
  root,
  'flavors:',
  for (final MapEntry(:key, :value) in flavors.entries) ...[
    '  $key:',
    '    app:',
    '      name: $key',
    if (value.isNotEmpty) value,
  ],
].join('\n');

void main() {
  group('badge', () {
    test('is off by default', () {
      final config = FlavorizrConfig.parse(_config(flavors: {'dev': ''}));

      expect(config.badge, isFalse);
      expect(config.badgeOf('dev'), isNull);
    });

    test('is on for every flavor when the root says so', () {
      final config = FlavorizrConfig.parse(
        _config(root: 'badge: true', flavors: {'dev': '', 'staging': ''}),
      );

      expect(config.badge, isTrue);
      expect(config.badgeOf('dev'), isNotNull);
      expect(config.badgeOf('staging'), isNotNull);
    });

    test('is on for the flavor that says so, and off for the others', () {
      final config = FlavorizrConfig.parse(
        _config(flavors: {'dev': '    badge: true', 'prod': ''}),
      );

      expect(config.badgeOf('dev'), isNotNull);
      expect(config.badgeOf('prod'), isNull);
    });

    test('is off for the flavor that opts out of the root', () {
      final config = FlavorizrConfig.parse(
        _config(
          root: 'badge: true',
          flavors: {'dev': '', 'prod': '    badge: false'},
        ),
      );

      expect(config.badgeOf('dev'), isNotNull);
      expect(config.badgeOf('prod'), isNull);
    });

    test('is on for a flavor with a map, even when the root is off', () {
      final config = FlavorizrConfig.parse(
        _config(
          root: 'badge: false',
          flavors: {'dev': '    badge: {label: BETA}', 'qa': '    badge: {}'},
        ),
      );

      expect(config.badgeOf('dev')!.label, 'BETA');
      expect(config.badgeOf('qa'), isNotNull);
    });

    test('has the upper-cased flavor name and the default colour', () {
      final config = FlavorizrConfig.parse(
        _config(root: 'badge: true', flavors: {'staging': ''}),
      );
      final badge = config.badgeOf('staging')!;

      expect(badge.label, 'STAGING');
      expect(badge.color, defaultBadgeColor('staging'));
      expect(badge.color, BadgeColor.parse('#8E24AA'));
      expect(badge.textColor, BadgeColor.white);
    });

    test('has the label and the colour of the flavor', () {
      final config = FlavorizrConfig.parse(
        _config(
          flavors: {'dev': '    badge: { label: DEV, color: "#FFEB3B" }'},
        ),
      );
      final badge = config.badgeOf('dev')!;

      expect(badge.label, 'DEV');
      expect(badge.color, BadgeColor.parse('#FFEB3B'));
      expect(badge.textColor, BadgeColor.black);
    });

    test('takes the label alone and the colour alone', () {
      final config = FlavorizrConfig.parse(
        _config(
          flavors: {
            'one': '    badge: {label: ONE}',
            'two': '    badge: {color: "#000000"}',
          },
        ),
      );

      expect(config.badgeOf('one')!.label, 'ONE');
      expect(config.badgeOf('one')!.color, defaultBadgeColor('one'));
      expect(config.badgeOf('two')!.label, 'TWO');
      expect(config.badgeOf('two')!.color, BadgeColor.black);
    });

    test('truncates a long label', () {
      final config = FlavorizrConfig.parse(
        _config(
          root: 'badge: true',
          flavors: {
            'production': '',
            'qa': '    badge: {label: Pre-production}',
          },
        ),
      );

      expect(config.badgeOf('production')!.label, 'PRODUCT…');
      expect(config.badgeOf('qa')!.label, 'Pre-pro…');
    });

    test('is not there for a flavor that does not exist', () {
      final config = FlavorizrConfig.parse(
        _config(root: 'badge: true', flavors: {'dev': ''}),
      );

      expect(config.badgeOf('nope'), isNull);
    });

    test('has the colour of a flavor from its name alone', () {
      final one = FlavorizrConfig.parse(
        _config(root: 'badge: true', flavors: {'dev': '', 'prod': ''}),
      );
      final other = FlavorizrConfig.parse(
        _config(root: 'badge: true', flavors: {'prod': ''}),
      );

      expect(one.badgeOf('prod')!.color, other.badgeOf('prod')!.color);
    });
  });

  group('icon', () {
    test('is the root icon, if there is one', () {
      expect(FlavorizrConfig.parse(_config(flavors: {'a': ''})).icon, isNull);
      expect(
        FlavorizrConfig.parse(
          _config(root: 'icon: assets/icon.png', flavors: {'a': ''}),
        ).icon,
        'assets/icon.png',
      );
    });
  });

  group('the fingerprint of a flavor', () {
    String? print(String yaml, [String flavor = 'dev']) =>
        FlavorizrConfig.parse(yaml).flavorFingerprints[flavor];

    test('does not change for a configuration that has neither key', () {
      final before = print(_config(flavors: {'dev': ''}));

      expect(before, print(_config(flavors: {'dev': ''})));
    });

    test('changes with the root badge, the root icon and the flavor badge', () {
      final plain = print(_config(flavors: {'dev': ''}));

      expect(
        print(_config(root: 'badge: true', flavors: {'dev': ''})),
        isNot(plain),
      );
      expect(
        print(_config(root: 'icon: a.png', flavors: {'dev': ''})),
        isNot(plain),
      );
      expect(
        print(_config(flavors: {'dev': '    badge: {label: X}'})),
        isNot(plain),
      );
    });
  });

  group('a badge that is wrong', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('badge_config'));
    tearDown(() => dir.deleteSync(recursive: true));

    Exception failure(String yaml) {
      File('${dir.path}/flavorizr.yaml').writeAsStringSync(yaml);

      try {
        Parser(
          pubspecPath: '${dir.path}/none',
          flavorizrPath: '${dir.path}/flavorizr',
        ).parse();
      } on Exception catch (e) {
        return e;
      }

      fail('Should have thrown');
    }

    test('names the key that is not known, with the one that was meant', () {
      final error = failure(
        _config(flavors: {'dev': '    badge: {lable: DEV}'}),
      );

      expect(error, isA<UnknownFieldsException>());
      error as UnknownFieldsException;
      expect(error.fields, ['lable']);
      expect(error.path, 'flavors.dev.badge');
      expect(error.suggestions, {'lable': 'label'});
      expect(error.allowedKeys, unorderedEquals(['label', 'color']));
    });

    test('says what a colour must look like', () {
      final error = failure(
        _config(flavors: {'dev': '    badge: {color: red}'}),
      );

      expect(error, isA<InvalidConfigurationException>());
      expect(error.toString(), contains('#RRGGBB'));
    });

    test('is not text or a map or a bool', () {
      expect(
        failure(_config(flavors: {'dev': '    badge: [1]'})),
        isA<InvalidConfigurationException>(),
      );
      expect(
        failure(_config(flavors: {'dev': '    badge: yes please'})),
        isA<InvalidConfigurationException>(),
      );
    });

    test('has a label that is empty', () {
      expect(
        failure(_config(flavors: {'dev': '    badge: {label: ""}'})),
        isA<InvalidConfigurationException>(),
      );
    });

    test('has a root that is not a bool', () {
      expect(
        failure(_config(root: 'badge: {label: X}', flavors: {'dev': ''})),
        isA<InvalidConfigurationException>(),
      );
    });

    test('accepts the root keys, and suggests them for a typo', () {
      final error = failure(_config(root: 'icn: a.png', flavors: {'dev': ''}));

      expect(error, isA<UnknownFieldsException>());
      expect((error as UnknownFieldsException).suggestions, {'icn': 'icon'});
      expect(error.allowedKeys, containsAll(['badge', 'icon']));
    });
  });
}
