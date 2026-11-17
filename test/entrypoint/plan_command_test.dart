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
import 'package:flutter_test/flutter_test.dart';

import 'cli_fixture.dart';

void main() {
  late CliFixture project;

  setUp(() => project = CliFixture());
  tearDown(() => project.dispose());

  group('plan', () {
    test('writes nothing, not even the lock', () async {
      final before = project.snapshot();

      final code = await project.run(['plan', ...engineTargets]);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.snapshot(), before);
      expect(project.questions, isEmpty);
      expect(project.legacy.ran, isEmpty);
    });

    test('shows the graph, with what was pulled in marked (auto)', () async {
      await project.run(['plan', ...engineTargets]);

      expect(
        project.logger.output,
        contains('2. android:flavorizrGradle (auto)\n  3. android:buildGradle'),
      );
    });

    test('shows the changes by platform with + ~ -', () async {
      await project.run(['plan', ...engineTargets]);

      expect(project.logger.output, contains('android\n'));
      expect(project.logger.output, contains('+ android/app/flavorizr.gradle'));
      expect(project.logger.output, contains('~ android/app/build.gradle'));
      expect(project.logger.output, contains('+ apple (added)'));
      expect(project.logger.output, contains('1 to add, 2 to change'));
    });

    test('shows what a dropped flavor takes away', () async {
      await project.run(['apply', '-y', ...engineTargets]);
      project.write('flavorizr.yaml', CliFixture.config(['apple']));

      final code = await project.run(['plan', ...engineTargets]);

      expect(code, ExitCodes.ok);
      expect(project.logger.output, contains('- banana (removed)'));
      expect(project.logger.output, contains('~ android/app/flavorizr.gradle'));
    });

    test('says that the project is up to date', () async {
      await project.run(['apply', '-y', ...engineTargets]);
      project.logger.lines.clear();

      final code = await project.run(['plan', ...engineTargets]);

      expect(code, ExitCodes.ok);
      expect(project.logger.output, contains('up to date'));
    });

    test('names the processors that are not on the engine', () async {
      await project.run(['plan', ...engineTargets, 'flutter:flavors']);

      expect(project.logger.output, contains('flutter:flavors'));
      expect(project.logger.output, contains('not on the engine yet'));
      expect(project.legacy.ran, isEmpty);
    });

    test('exits with 1 when a file edited by hand is in the way', () async {
      await project.run(['apply', '-y', ...engineTargets]);
      project.write('android/app/flavorizr.gradle', '// mine\n');
      project.write('flavorizr.yaml', CliFixture.config(['apple', 'pear']));

      final code = await project.run(['plan', ...engineTargets]);

      expect(code, ExitCodes.attention);
      expect(project.logger.output, contains('[conflict]'));
      expect(project.logger.output, contains('1 conflict'));
      expect(project.read('android/app/flavorizr.gradle'), '// mine\n');
    });

    test('exits with 70 when a processor fails', () async {
      File(
        project.abs('android/app/src/main/AndroidManifest.xml'),
      ).deleteSync();

      final code = await project.run(['plan', 'android:androidManifest']);

      expect(code, ExitCodes.software);
      expect(
        project.logger.output,
        contains('Failed: android:androidManifest'),
      );
    });

    test('an unknown target is 64', () async {
      expect(await project.run(['plan', 'nope']), ExitCodes.usage);
    });

    test(
      'the plan of a platform without flavors is skipped, with a reason',
      () async {
        final code = await project.run(['plan', 'ios']);

        expect(code, ExitCodes.ok);
        expect(
          project.logger.output,
          contains('no flavors are configured for ios'),
        );
        expect(project.logger.output, contains('nothing to run'));
      },
    );
  });
}
