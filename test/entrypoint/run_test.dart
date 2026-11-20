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
import 'package:test/test.dart';

import 'cli_fixture.dart';

void main() {
  late CliFixture project;

  setUp(() => project = CliFixture());
  tearDown(() => project.dispose());

  group('no command', () {
    test('behaves like apply', () async {
      final explicit = CliFixture();
      addTearDown(explicit.dispose);

      final implicitCode = await project.run([]);
      final explicitCode = await explicit.run(['apply']);

      expect(implicitCode, explicitCode);
      expect(implicitCode, ExitCodes.ok, reason: project.logger.output);
      expect(project.snapshot(), explicit.snapshot());
      expect(project.questions, explicit.questions);
      expect(project.questions, ['Do you want to proceed?']);
      expect(project.exists('flavorizr.lock'), isTrue);
    });

    test('the options of apply still work', () async {
      final code = await project.run(['--yes', 'android:buildGradle']);

      expect(code, ExitCodes.ok);
      expect(project.questions, isEmpty);
      expect(project.exists('android/app/flavorizr.gradle'), isTrue);
    });

    test('a target is a target of apply', () async {
      final code = await project.run(['android:flavorizrGradle', '-y']);

      expect(code, ExitCodes.ok);
      expect(project.exists('android/app/flavorizr.gradle'), isTrue);
    });

    test('2.x style: -f alone applies everything without asking', () async {
      final code = await project.run(['-f']);

      expect(code, ExitCodes.ok);
      expect(project.questions, isEmpty);
      expect(project.exists('flavorizr.lock'), isTrue);
    });

    test('the default recipe of the configuration is what runs', () async {
      project.write(
        'flavorizr.yaml',
        CliFixture.config([
          'apple',
        ], extra: 'recipes:\n  default:\n    - android:flavorizrGradle\n'),
      );

      final code = await project.run(['-f']);

      expect(code, ExitCodes.ok);
      expect(project.exists('android/app/flavorizr.gradle'), isTrue);
      expect(
        project.read('android/app/build.gradle'),
        isNot(contains('flavorizr.gradle')),
      );
    });

    test('--verbose is accepted before the command too', () async {
      final code = await project.run(['-v', 'plan', 'android:buildGradle']);

      expect(code, ExitCodes.ok);
    });
  });

  group('help', () {
    test('--help lists the commands and the exit codes', () async {
      final code = await project.run(['--help']);

      expect(code, ExitCodes.ok);
      for (final command in ['apply', 'plan', 'status', 'list', 'doctor']) {
        expect(project.logger.output, contains(command));
      }
      expect(project.logger.output, contains('Exit codes'));
      expect(project.snapshot().keys, isNot(contains('flavorizr.lock')));
    });

    for (final command in ['apply', 'plan', 'status', 'list', 'doctor']) {
      test(
        '$command --help describes the command and the exit codes',
        () async {
          final before = project.snapshot();

          final code = await project.run([command, '--help']);

          expect(code, ExitCodes.ok);
          expect(project.logger.output, contains(command));
          expect(project.logger.output, contains('--verbose'));
          expect(project.logger.output, contains('Exit codes'));
          expect(project.snapshot(), before);
        },
      );
    }

    test('apply --help documents --yes and --on-conflict', () async {
      await project.run(['apply', '-h']);

      expect(project.logger.output, contains('--yes'));
      expect(project.logger.output, contains('--on-conflict'));
    });

    test('2.x options are not advertised', () async {
      await project.run(['apply', '--help']);

      expect(project.logger.output, isNot(contains('--force')));
      expect(project.logger.output, isNot(contains('--processors')));
    });

    test('the help of a command is reached from help too', () async {
      final code = await project.run(['help', 'plan']);

      expect(code, ExitCodes.ok);
      expect(project.logger.output, contains('plan'));
    });
  });

  group('the command', () {
    test('is not the value of an option', () async {
      final code = await project.run(['-p', 'android:flavorizrGradle', '-y']);

      expect(code, ExitCodes.ok);
      expect(project.exists('android/app/flavorizr.gradle'), isTrue);
    });

    test(
      'a command name that is the value of -p is an unknown target',
      () async {
        final code = await project.run(['-p', 'list']);

        expect(code, ExitCodes.usage);
      },
    );
  });

  group('usage errors', () {
    test('an option nobody knows is 64', () async {
      final code = await project.run(['apply', '--nope']);

      expect(code, ExitCodes.usage);
      expect(project.logger.errors, isNotEmpty);
    });

    test('a word nobody knows is an unknown target, 64', () async {
      final code = await project.run(['frobnicate']);

      expect(code, ExitCodes.usage);
    });
  });
}
