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
import 'package:flutter_flavorizr/src/parser/parser.dart';
import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:flutter_test/flutter_test.dart';

String _config(String android) => '''
flavors:
  apple:
    app:
      name: Apple
    android:
      applicationId: com.example.apple
$android''';

void main() {
  late Directory temp;

  setUp(() => temp = Directory.systemTemp.createTempSync('custom_config'));

  tearDown(() => temp.deleteSync(recursive: true));

  FlavorizrConfig parse(String content) {
    File('${temp.path}/flavorizr.yaml').writeAsStringSync(content);

    return Parser(
      pubspecPath: '${temp.path}/pubspec',
      flavorizrPath: '${temp.path}/flavorizr',
    ).parse();
  }

  InvalidConfigurationException fails(String content) {
    try {
      parse(content);
    } on InvalidConfigurationException catch (e) {
      return e;
    }

    fail('the configuration was accepted');
  }

  group('customConfig and manifestPlaceholders', () {
    test('read text, numbers, booleans, lists and maps as they are', () {
      final android = parse(
        _config('''
      customConfig:
        versionNameSuffix: -green
        versionCode: 3
        isDefault: true
        resourceConfigurations: [en, it]
        signingConfig: {raw: flavorSigning.green}
      manifestPlaceholders:
        scheme: com.example
        retries: 2
'''),
      ).androidFlavors['apple']!.android!;

      expect(android.customConfig, {
        'versionNameSuffix': '-green',
        'versionCode': 3,
        'isDefault': true,
        'resourceConfigurations': ['en', 'it'],
        'signingConfig': {'raw': 'flavorSigning.green'},
      });
      expect(android.manifestPlaceholders, {
        'scheme': 'com.example',
        'retries': 2,
      });
    });

    test('a flavor has no placeholders by default', () {
      expect(
        parse(
          _config(''),
        ).androidFlavors['apple']!.android!.manifestPlaceholders,
        isEmpty,
      );
    });

    test('a text with the quotes 2.x asked for fails, with where it is', () {
      final error = fails(
        _config(r'''
      customConfig:
        versionNameSuffix: "\"-uat\""
'''),
      );

      expect(error.location, 'flavorizr.yaml:8:28');
      expect(
        error.message,
        contains('flavors.apple.android.customConfig.versionNameSuffix'),
      );
      expect(error.message, contains('quotes'));
      expect(error.message, contains('(-uat)'));
    });

    test(
      'quotes inside a list or a map fail too, and inside a raw they do not',
      () {
        expect(
          fails(
            _config(r'''
      customConfig:
        flags: ["\"a\""]
'''),
          ).message,
          contains('customConfig.flags.0'),
        );
        expect(
          fails(
            _config(r'''
      customConfig:
        nested: {inner: "\"a\""}
'''),
          ).message,
          contains('customConfig.nested.inner'),
        );
        expect(
          () => parse(
            _config(r'''
      customConfig:
        suffix: {raw: "\"-uat\""}
'''),
          ),
          returnsNormally,
        );
      },
    );

    test('a manifestPlaceholders in customConfig says where it goes', () {
      final error = fails(
        _config('''
      customConfig:
        manifestPlaceholders: += ['scheme':'x']
'''),
      );

      expect(error.location, 'flavorizr.yaml:8:9');
      expect(
        error.message,
        contains('flavors.apple.android.manifestPlaceholders'),
      );
    });
  });
}
