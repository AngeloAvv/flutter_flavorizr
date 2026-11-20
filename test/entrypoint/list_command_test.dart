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

import 'package:flutter_flavorizr/src/entrypoint/exit_codes.dart';
import 'package:test/test.dart';

import 'cli_fixture.dart';

void main() {
  late CliFixture project;

  setUp(() => project = CliFixture());
  tearDown(() => project.dispose());

  group('list', () {
    test('lists the built-in recipes and marks the default', () async {
      final code = await project.run(['list']);

      expect(code, ExitCodes.ok);
      expect(project.logger.output, contains('all (built-in, default)'));
      expect(project.logger.output, contains('android (built-in)'));
      expect(project.logger.output, contains('icons (built-in)'));
    });

    test('lists the recipes of flavorizr.yaml, and the default one', () async {
      project.write(
        'flavorizr.yaml',
        CliFixture.config(
          ['apple'],
          extra: '''
recipes:
  ci: [android, "huawei:agconnect"]
  default: ci
''',
        ),
      );

      final code = await project.run(['list']);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.logger.output, contains('ci (default)'));
      expect(
        project.logger.output,
        contains('contains: android, huawei:agconnect'),
      );
      expect(project.logger.output, contains('all (built-in)\n'));
    });

    test('lists every processor and where it runs', () async {
      await project.run(['list']);

      expect(project.logger.output, contains('android:icons [engine]'));
      expect(project.logger.output, contains('android:dummyAssets [legacy]'));
      expect(project.logger.output, contains('huawei:agconnect [engine]'));
      expect(project.logger.output, contains('ios:podfile [engine]'));
      expect(project.logger.output, contains('ios:buildTargets [engine]'));
      expect(project.logger.output, contains('ios:schema [engine]'));
      expect(project.logger.output, contains('macos:schema [engine]'));
    });

    test('draws what a processor needs and what it runs after', () async {
      await project.run(['list']);

      expect(
        project.logger.output,
        contains(
          'android:buildGradle [engine]\n'
          '    └─ needs android:flavorizrGradle',
        ),
      );
      expect(
        project.logger.output,
        contains(
          'android:icons [engine]\n'
          '    └─ after android:dummyAssets (legacy)',
        ),
      );
    });

    test('works in a folder with no configuration', () async {
      File(project.abs('flavorizr.yaml')).deleteSync();

      final code = await project.run(['list']);

      expect(code, ExitCodes.ok);
      expect(project.logger.output, contains('android:icons [engine]'));
    });

    test('works when pubspec.yaml has no flavorizr section', () async {
      File(project.abs('flavorizr.yaml')).deleteSync();
      project.write('pubspec.yaml', 'name: app\n');

      expect(await project.run(['list']), ExitCodes.ok);
    });

    test('is 65 when flavorizr.yaml cannot be read, and says why', () async {
      project.write('flavorizr.yaml', 'flavors: [');

      final code = await project.run(['list']);

      expect(code, ExitCodes.data);
      expect(project.logger.errors, isNotEmpty);
      expect(project.logger.output, isNot(contains('android:icons [engine]')));
    });

    test('is 65 when flavorizr.yaml has no flavors', () async {
      project.write('flavorizr.yaml', 'recipes:\n  ci: [android]\n');

      expect(await project.run(['list']), ExitCodes.data);
    });

    test('is 65 when a recipe of flavorizr.yaml is not valid', () async {
      project.write(
        'flavorizr.yaml',
        CliFixture.config(['apple'], extra: 'recipes:\n  plan: [android]\n'),
      );

      final code = await project.run(['list']);

      expect(code, ExitCodes.data);
      expect(project.logger.errors.join(), contains('plan'));
    });

    test('writes nothing', () async {
      final before = project.snapshot();

      await project.run(['list']);

      expect(project.snapshot(), before);
    });
  });
}
