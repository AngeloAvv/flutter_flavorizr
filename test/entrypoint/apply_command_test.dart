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

/// The processors of a run that writes something of every kind.
const engine = [
  'flutter:flavors',
  'android:androidManifest',
  'android:buildGradle',
  'android:dummyAssets',
  'android:icons',
];

void main() {
  late CliFixture project;

  setUp(() => project = CliFixture());
  tearDown(() => project.dispose());

  group('apply', () {
    test('runs the processors of the engine and writes the lock', () async {
      final code = await project.run(['apply', '--yes', ...engine]);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.read('android/app/flavorizr.gradle'), contains('apple'));
      expect(
        project.read('android/app/build.gradle'),
        contains('apply from: "flavorizr.gradle"'),
      );
      expect(
        project.read('android/app/src/main/AndroidManifest.xml'),
        contains('@string/app_name'),
      );

      final lock = project.read('flavorizr.lock');

      expect(lock, contains('flavorizrVersion: 3.0.0'));
      expect(lock, contains('apple: sha256:'));
      expect(lock, contains('android/app/flavorizr.gradle'));
    });

    test('shows the plan and the changes before it asks', () async {
      await project.run(['apply', ...engine]);

      expect(project.questions, ['Do you want to proceed?']);
      expect(project.logger.output, contains('android:flavorizrGradle'));
      expect(project.logger.output, contains('(auto)'));
      expect(project.logger.output, contains('+ android/app/flavorizr.gradle'));
    });

    test('--yes does not ask', () async {
      await project.run(['apply', '--yes', ...engine]);

      expect(project.questions, isEmpty);
    });

    test('-y is --yes', () async {
      await project.run(['apply', '-y', ...engine]);

      expect(project.questions, isEmpty);
      expect(project.exists('android/app/flavorizr.gradle'), isTrue);
    });

    test('-f, which 2.x used, is --yes too', () async {
      final code = await project.run(['-f', ...engine]);

      expect(code, ExitCodes.ok);
      expect(project.questions, isEmpty);
      expect(project.exists('android/app/flavorizr.gradle'), isTrue);
    });

    test('-p, which 2.x used, names the targets', () async {
      final code = await project.run(['-f', '-p', 'android:flavorizrGradle']);

      expect(code, ExitCodes.ok);
      expect(project.exists('android/app/flavorizr.gradle'), isTrue);
      expect(
        project.read('android/app/build.gradle'),
        isNot(contains('flavorizr.gradle')),
      );
    });

    test('writes nothing and succeeds when the answer is no', () async {
      project.answer = false;
      final before = project.snapshot();

      final code = await project.run(['apply', ...engine]);

      expect(code, ExitCodes.ok);
      expect(project.snapshot(), before);
      expect(project.logger.output, contains('cancelled'));
    });

    test('does not ask again when nothing changes', () async {
      await project.run(['apply', '--yes', ...engine]);
      final lock = project.read('flavorizr.lock');
      project.questions.clear();

      final code = await project.run(['apply', ...engine]);

      expect(code, ExitCodes.ok);
      expect(project.questions, isEmpty);
      expect(project.read('flavorizr.lock'), lock);
      expect(project.logger.output, contains('up to date'));
    });

    test('removes what a dropped flavor generated', () async {
      await project.run(['apply', '--yes', ...engine]);
      project.write('flavorizr.yaml', CliFixture.config(['apple']));

      final code = await project.run(['apply', '--yes', ...engine]);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(
        project.read('android/app/flavorizr.gradle'),
        isNot(contains('banana')),
      );
      expect(project.read('flavorizr.lock'), isNot(contains('banana')));
    });

    group('conflicts', () {
      Future<void> editByHand() async {
        await project.run(['apply', '--yes', ...engine]);
        project.write('android/app/flavorizr.gradle', '// mine\n');
        project.write('flavorizr.yaml', CliFixture.config(['apple', 'pear']));
      }

      test('fail with --yes, and nothing is written', () async {
        await editByHand();
        final before = project.snapshot();

        final code = await project.run(['apply', '--yes', ...engine]);

        expect(code, ExitCodes.attention);
        expect(project.snapshot(), before);
        expect(project.logger.output, contains('flavorizr.gradle'));
        expect(project.logger.output, contains('--on-conflict'));
      });

      test('fail when nobody can answer', () async {
        await editByHand();

        final code = await project.run(['apply', ...engine]);

        expect(code, ExitCodes.attention);
      });

      test('are overwritten with --on-conflict=overwrite', () async {
        await editByHand();

        final code = await project.run([
          'apply',
          '--yes',
          '--on-conflict=overwrite',
          ...engine,
        ]);

        expect(code, ExitCodes.ok, reason: project.logger.output);
        expect(project.read('android/app/flavorizr.gradle'), contains('pear'));
      });

      test('are left alone with --on-conflict=keep', () async {
        await editByHand();

        final code = await project.run([
          'apply',
          '--yes',
          '--on-conflict=keep',
          ...engine,
        ]);

        expect(code, ExitCodes.ok, reason: project.logger.output);
        expect(project.read('android/app/flavorizr.gradle'), '// mine\n');
      });

      test('an unknown policy is a usage error', () async {
        final code = await project.run(['apply', '--on-conflict=ask']);

        expect(code, ExitCodes.usage);
      });
    });

    test('with an empty default recipe and no target runs nothing', () async {
      project.write(
        'flavorizr.yaml',
        CliFixture.config(['apple'], extra: 'recipes:\n  default: []\n'),
      );
      final before = project.snapshot();

      final code = await project.run(['apply', '--yes']);

      expect(code, ExitCodes.ok);
      expect(project.snapshot(), before);
      expect(project.logger.output, contains('nothing to run'));
    });

    group('the lock', () {
      test('that cannot be staged stops the run before it writes', () async {
        Process.runSync('chmod', ['555', project.root.path]);
        addTearDown(() => Process.runSync('chmod', ['755', project.root.path]));
        final before = project.snapshot();

        final code = await project.run(['apply', '--yes', ...engine]);

        expect(code, ExitCodes.software);
        expect(project.snapshot(), before);
        expect(project.exists('android/app/flavorizr.gradle'), isFalse);
      }, skip: Platform.isWindows ? 'needs POSIX permissions' : false);

      test('that cannot be replaced is a partial application', () async {
        Directory(project.abs('flavorizr.lock')).createSync();

        final code = await project.run(['apply', '--yes', ...engine]);

        expect(code, ExitCodes.software);
        expect(project.exists('android/app/flavorizr.gradle'), isTrue);
        expect(project.logger.errors.join(), contains('already written'));
        expect(project.logger.errors.join(), contains('flavorizr.lock'));
        expect(
          project.root.listSync().map((e) => e.path),
          isNot(contains(endsWith('.tmp'))),
        );
      });
    });

    group('exit codes', () {
      test('an unknown target is a usage error, with a suggestion', () async {
        final code = await project.run(['apply', 'andriod']);

        expect(code, ExitCodes.usage);
        expect(
          project.logger.errors.join(),
          contains('Did you mean "android"'),
        );
      });

      test('a configuration that cannot be read is 65', () async {
        project.write('flavorizr.yaml', 'flavors: [');

        expect(await project.run(['apply', '--yes']), ExitCodes.data);
      });

      test('no configuration is 65', () async {
        File(project.abs('flavorizr.yaml')).deleteSync();

        expect(await project.run(['apply', '--yes']), ExitCodes.data);
      });

      test('a malformed lock is 65', () async {
        project.write('flavorizr.lock', 'not: [a lock');

        expect(
          await project.run(['apply', '--yes', ...engine]),
          ExitCodes.data,
        );
      });

      test('a lock of a newer flavorizr is 65', () async {
        project.write(
          'flavorizr.lock',
          'flavorizrVersion: 9.0.0\nflavors: {}\nprocessors: {}\n'
              'schemaVersion: 1\n',
        );

        expect(
          await project.run(['apply', '--yes', ...engine]),
          ExitCodes.data,
        );
      });

      test('a failing processor is 70 and nothing is written', () async {
        File(
          project.abs('android/app/src/main/AndroidManifest.xml'),
        ).deleteSync();
        final before = project.snapshot();

        final code = await project.run(['apply', '--yes', ...engine]);

        expect(code, ExitCodes.software);
        expect(project.snapshot(), before);
        expect(
          project.logger.output,
          contains('Failed: android:androidManifest'),
        );
      });
    });

    group('android:dummyAssets', () {
      test('runs on the engine with the others', () async {
        final code = await project.run([
          'apply',
          '--yes',
          'android:flavorizrGradle',
          'android:dummyAssets',
        ]);

        expect(code, ExitCodes.ok, reason: project.logger.output);
        expect(project.exists('android/app/flavorizr.gradle'), isTrue);
        expect(project.logger.output, contains('android:dummyAssets'));
        expect(project.logger.output, isNot(contains('not on the engine')));
      });

      test('makes nothing', () async {
        final before = project.snapshot();

        final code = await project.run([
          'apply',
          '--yes',
          'android:dummyAssets',
        ]);

        expect(code, ExitCodes.ok, reason: project.logger.output);
        expect(
          project.snapshot().keys.toSet().difference(before.keys.toSet()),
          {'flavorizr.lock'},
        );
        expect(project.exists('android/app/src/apple'), isFalse);
      });
    });
  });
}
