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

import 'dart:io';

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
    '    ios:',
    '      bundleId: com.example.$key',
    if (value.isNotEmpty) value,
  ],
].join('\n');

void main() {
  group('launchScreen', () {
    test('is off by default', () {
      final config = FlavorizrConfig.parse(_config(flavors: {'dev': ''}));

      expect(config.launchScreen, isFalse);
      expect(config.launchScreenOf('dev'), isFalse);
      expect(config.launchScreenFlavors, isEmpty);
    });

    test('is on for every iOS flavor when the root says so', () {
      final config = FlavorizrConfig.parse(
        _config(root: 'launchScreen: true', flavors: {'dev': '', 'prod': ''}),
      );

      expect(config.launchScreen, isTrue);
      expect(config.launchScreenOf('dev'), isTrue);
      expect(config.launchScreenOf('prod'), isTrue);
      expect(config.launchScreenFlavors.keys, ['dev', 'prod']);
    });

    test('is on for the flavor that says so, and off for the others', () {
      final config = FlavorizrConfig.parse(
        _config(flavors: {'dev': '    launchScreen: true', 'prod': ''}),
      );

      expect(config.launchScreenOf('dev'), isTrue);
      expect(config.launchScreenOf('prod'), isFalse);
      expect(config.launchScreenFlavors.keys, ['dev']);
    });

    test('is off for the flavor that opts out of the root', () {
      final config = FlavorizrConfig.parse(
        _config(
          root: 'launchScreen: true',
          flavors: {'dev': '', 'prod': '    launchScreen: false'},
        ),
      );

      expect(config.launchScreenOf('dev'), isTrue);
      expect(config.launchScreenOf('prod'), isFalse);
    });

    test('is off for a flavor that is not built for iOS, and for one that '
        'is not there', () {
      final config = FlavorizrConfig.parse('''
launchScreen: true
flavors:
  web:
    app:
      name: Web
    android:
      applicationId: com.example.web
''');

      expect(config.launchScreenOf('web'), isFalse);
      expect(config.launchScreenOf('nope'), isFalse);
      expect(config.launchScreenFlavors, isEmpty);
    });

    test('changes the fingerprint of the flavors, at the root and in them', () {
      final base = FlavorizrConfig.parse(_config(flavors: {'dev': ''}));
      final root = FlavorizrConfig.parse(
        _config(root: 'launchScreen: true', flavors: {'dev': ''}),
      );
      final flavor = FlavorizrConfig.parse(
        _config(flavors: {'dev': '    launchScreen: true'}),
      );

      expect(
        root.flavorFingerprints['dev'],
        isNot(base.flavorFingerprints['dev']),
      );
      expect(
        flavor.flavorFingerprints['dev'],
        isNot(base.flavorFingerprints['dev']),
      );
    });
  });

  group('a launchScreen that is wrong', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('launch_config'));
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

    test('is not a bool', () {
      expect(
        failure(_config(root: 'launchScreen: [1]', flavors: {'dev': ''})),
        isA<InvalidConfigurationException>(),
      );
      expect(
        failure(_config(flavors: {'dev': '    launchScreen: yes please'})),
        isA<InvalidConfigurationException>(),
      );
    });

    test('is a known key, suggested for a typo', () {
      final error = failure(
        _config(root: 'launchScren: true', flavors: {'dev': ''}),
      );

      expect(error, isA<UnknownFieldsException>());
      error as UnknownFieldsException;
      expect(error.suggestions, {'launchScren': 'launchScreen'});
      expect(error.allowedKeys, contains('launchScreen'));

      final inFlavor = failure(
        _config(flavors: {'dev': '    launchScren: true'}),
      );

      expect(inFlavor, isA<UnknownFieldsException>());
      expect((inFlavor as UnknownFieldsException).suggestions, {
        'launchScren': 'launchScreen',
      });
    });
  });
}
