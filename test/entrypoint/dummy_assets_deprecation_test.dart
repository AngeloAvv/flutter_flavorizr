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

import 'package:flutter_flavorizr/src/entrypoint/exit_codes.dart';
import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:flutter_test/flutter_test.dart';

import 'cli_fixture.dart';

const _flavors = '''
flavors:
  apple:
    app:
      name: Apple
    android:
      applicationId: com.example.apple
      generateDummyAssets: false
    ios:
      bundleId: com.example.apple
      generateDummyAssets: true
    macos:
      bundleId: com.example.apple
    windows:
      generateDummyAssets: false
  banana:
    app:
      name: Banana
    android:
      applicationId: com.example.banana
''';

void main() {
  group('generateDummyAssets', () {
    test('is deprecated: the configuration lists where it is, and it still '
        'reads', () {
      final config = FlavorizrConfig.parse(_flavors);

      expect(config.deprecations, hasLength(3));
      expect(
        config.deprecations.first,
        allOf(
          startsWith('`flavors.apple.android.generateDummyAssets`'),
          contains('deprecated and ignored'),
          contains('default icon of the project'),
        ),
      );
      expect(config.deprecations[1], contains('flavors.apple.ios.'));
      expect(config.deprecations[2], contains('flavors.apple.windows.'));
    });

    test('is not mentioned by a configuration that does not use it', () {
      expect(
        FlavorizrConfig.parse(CliFixture.config(['apple'])).deprecations,
        isEmpty,
      );
    });

    test(
      'is warned about by the commands, once, and the run goes on',
      () async {
        final project = CliFixture();
        addTearDown(project.dispose);
        project.write('flavorizr.yaml', '''
flavors:
  apple:
    app:
      name: Apple
    android:
      applicationId: com.example.apple
      generateDummyAssets: false
''');

        final code = await project.run(['plan']);

        expect(code, ExitCodes.ok, reason: project.logger.output);
        expect(
          project.logger.warnings.where(
            (w) => w.contains('generateDummyAssets'),
          ),
          hasLength(1),
        );
      },
    );
  });
}
