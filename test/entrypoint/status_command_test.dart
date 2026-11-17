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

  Future<int> status() => project.run(['status', ...engineTargets]);

  group('status', () {
    test('exits with 1 on a project that was never flavorized', () async {
      final code = await status();

      expect(code, ExitCodes.attention);
      expect(project.logger.output, contains('flavorizr.lock does not exist'));
      expect(project.logger.output, contains('+ apple (added)'));
      expect(project.logger.output, contains('drifted'));
    });

    test('exits with 0 once everything was applied', () async {
      await project.run(['apply', '-y', ...engineTargets]);

      final code = await status();

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.logger.output, contains('In sync'));
    });

    test('exits with 1 when flavorizr.yaml has a new flavor', () async {
      await project.run(['apply', '-y', ...engineTargets]);
      project.write(
        'flavorizr.yaml',
        CliFixture.config(['apple', 'banana', 'pear']),
      );

      final code = await status();

      expect(code, ExitCodes.attention);
      expect(project.logger.output, contains('+ pear (added)'));
      expect(project.logger.output, contains('~ android/app/flavorizr.gradle'));
    });

    test('exits with 1 when a flavor of flavorizr.yaml changed', () async {
      await project.run(['apply', '-y', ...engineTargets]);
      project.write(
        'flavorizr.yaml',
        CliFixture.config([
          'apple',
          'banana',
        ]).replaceFirst('apple app', 'Pear'),
      );

      final code = await status();

      expect(code, ExitCodes.attention);
      expect(project.logger.output, contains('~ apple (changed)'));
    });

    test(
      'exits with 1 when a flavor was dropped from flavorizr.yaml',
      () async {
        await project.run(['apply', '-y', ...engineTargets]);
        project.write('flavorizr.yaml', CliFixture.config(['apple']));

        final code = await status();

        expect(code, ExitCodes.attention);
        expect(project.logger.output, contains('- banana (removed)'));
      },
    );

    test('exits with 1 when a generated file was edited by hand', () async {
      await project.run(['apply', '-y', ...engineTargets]);
      project.write('android/app/flavorizr.gradle', '// mine\n');

      final code = await status();

      expect(code, ExitCodes.attention);
      expect(project.logger.output, contains('edited by hand'));
      expect(project.logger.output, contains('android/app/flavorizr.gradle'));
    });

    test('exits with 1 when a generated file is gone', () async {
      await project.run(['apply', '-y', ...engineTargets]);
      File(project.abs('android/app/flavorizr.gradle')).deleteSync();

      final code = await status();

      expect(code, ExitCodes.attention);
      expect(project.logger.output, contains('+ android/app/flavorizr.gradle'));
    });

    test(
      'is not drift when the user edits the rest of a patched file',
      () async {
        await project.run(['apply', '-y', ...engineTargets]);
        project.write(
          'android/app/build.gradle',
          '${project.read('android/app/build.gradle')}\n// my own line\n',
        );

        expect(await status(), ExitCodes.ok, reason: project.logger.output);
      },
    );

    test('writes nothing', () async {
      await project.run(['apply', '-y', ...engineTargets]);
      project.write('flavorizr.yaml', CliFixture.config(['apple']));
      final before = project.snapshot();

      await status();

      expect(project.snapshot(), before);
      expect(project.questions, isEmpty);
    });

    test('tells what it cannot check', () async {
      await project.run(['apply', '-y', ...engineTargets]);

      final code = await project.run([
        'status',
        ...engineTargets,
        'flutter:flavors',
      ]);

      expect(code, ExitCodes.ok);
      expect(project.logger.output, contains('Not checked'));
      expect(project.logger.output, contains('as far as the engine can tell'));
      expect(project.logger.output, contains('flutter:flavors'));
    });

    group('when no processor of the engine is selected', () {
      test('does not claim the project is in sync', () async {
        final code = await project.run(['status', 'flutter:flavors']);

        expect(code, ExitCodes.ok);
        expect(project.logger.output, contains('Nothing to check'));
        expect(project.logger.output, isNot(contains('In sync')));
      });

      test('a missing lock is not drift: nothing would ever write it', () async {
        // Only a run of the engine writes the lock, so a project with no
        // Android flavors never has one: calling that drift would be a failure
        // `apply` cannot fix.
        final iosOnly = CliFixture(android: false);
        addTearDown(iosOnly.dispose);
        iosOnly.write(
          'flavorizr.yaml',
          'flavors:\n  apple:\n    app:\n      name: Apple\n'
              '    ios:\n      bundleId: com.example.apple\n',
        );

        expect(await iosOnly.run(['apply', '--yes']), ExitCodes.ok);
        expect(iosOnly.exists('flavorizr.lock'), isFalse);
        expect(await iosOnly.run(['status']), ExitCodes.ok);
        expect(iosOnly.logger.output, contains('Nothing to check'));
      });
    });

    test('is 70 when a processor fails', () async {
      File(
        project.abs('android/app/src/main/AndroidManifest.xml'),
      ).deleteSync();

      expect(
        await project.run(['status', 'android:androidManifest']),
        ExitCodes.software,
      );
    });

    test('is 65 on a lock that cannot be read', () async {
      project.write('flavorizr.lock', '[');

      expect(await status(), ExitCodes.data);
    });
  });
}
