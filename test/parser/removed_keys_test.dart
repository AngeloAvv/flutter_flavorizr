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

import 'package:flutter_flavorizr/src/exception/invalid_configuration_exception.dart';
import 'package:flutter_flavorizr/src/parser/parser.dart';
import 'package:flutter_test/flutter_test.dart';

const _flavors = '''
flavors:
  apple:
    app:
      name: Apple
    android:
      applicationId: com.example.apple
''';

void main() {
  late Directory temp;

  setUp(() => temp = Directory.systemTemp.createTempSync('removed_keys'));

  tearDown(() => temp.deleteSync(recursive: true));

  RemovedKeyException removed(String file, String content) {
    File('${temp.path}/$file').writeAsStringSync(content);

    try {
      Parser(
        pubspecPath: '${temp.path}/pubspec',
        flavorizrPath: '${temp.path}/flavorizr',
      ).parse();
    } on RemovedKeyException catch (e) {
      return e;
    }

    fail('the configuration was accepted');
  }

  group('`instructions`, which `recipes` replaces', () {
    test('shows the yaml to write instead, with the same list', () {
      final error = removed(
        'flavorizr.yaml',
        '$_flavors'
            'instructions:\n  - android:icons\n  - "ios:plist"\n',
      );

      expect(error.key, 'instructions');
      expect(error.location, 'flavorizr.yaml:7:1');
      expect(
        error.message,
        '`instructions` is not a key of flavorizr 3.0: `recipes` replaces it, '
        'and the recipe `default` is what runs without a target. Write:\n\n'
        '    recipes:\n'
        '      default:\n'
        '        - android:icons\n'
        '        - ios:plist\n',
      );
    });

    test('keeps an empty list, which runs nothing', () {
      final error = removed(
        'flavorizr.yaml',
        '$_flavors'
            'instructions: []\n',
      );

      expect(error.message, endsWith('    recipes:\n      default: []\n'));
    });

    test('nests the yaml under `flavorizr` in a pubspec', () {
      final error = removed(
        'pubspec.yaml',
        'name: app\nflavorizr:\n  instructions:\n    - android:icons\n'
            '${_flavors.split('\n').map((line) => line.isEmpty ? line : '  $line').join('\n')}',
      );

      expect(error.location, 'pubspec.yaml:3:3');
      expect(
        error.message,
        endsWith(
          '    flavorizr:\n'
          '      recipes:\n'
          '        default:\n'
          '          - android:icons\n',
        ),
      );
    });

    test('says to add `default` to the recipes that exist', () {
      final error = removed(
        'flavorizr.yaml',
        '$_flavors'
            'recipes:\n  ci: [android:icons]\n'
            'instructions:\n  - android:icons\n',
      );

      expect(error.message, contains('Add `default` to your `recipes`:'));
    });

    test('does not show a list it cannot copy', () {
      final error = removed(
        'flavorizr.yaml',
        '$_flavors'
            'instructions:\n  - android:icons\n  - {a: b}\n',
      );

      expect(
        error.message,
        endsWith('Write the list of `instructions` as `default`.'),
      );
    });

    test('is not read in the sections of a pubspec that are not its own', () {
      File('${temp.path}/pubspec.yaml').writeAsStringSync(
        'name: app\ninstructions: whatever\nflavorizr:\n'
        '${_flavors.split('\n').map((line) => line.isEmpty ? line : '  $line').join('\n')}',
      );

      final flavorizr = Parser(
        pubspecPath: '${temp.path}/pubspec',
        flavorizrPath: '${temp.path}/flavorizr',
      ).parse();

      expect(flavorizr.flavors.keys, ['apple']);
    });
  });

  group('`assetsUrl`, which nothing downloads from anymore', () {
    test('is an error to remove, with where it is', () {
      final error = removed(
        'flavorizr.yaml',
        '$_flavors'
            'assetsUrl: https://example.com/assets.zip\n',
      );

      expect(error.key, 'assetsUrl');
      expect(error.location, 'flavorizr.yaml:7:1');
      expect(error.message, contains('nothing is downloaded'));
      expect(error.message, contains('Remove it'));
    });

    test('is found in the flavorizr section of a pubspec too', () {
      final error = removed(
        'pubspec.yaml',
        'name: app\nflavorizr:\n  assetsUrl: x\n  flavors:\n    apple:\n'
            '      app:\n        name: Apple\n',
      );

      expect(error.key, 'assetsUrl');
      expect(error.location, 'pubspec.yaml:3:3');
    });
  });
}
