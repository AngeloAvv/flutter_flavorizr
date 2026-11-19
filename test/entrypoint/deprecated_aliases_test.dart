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

/// The processors that run on the engine, so that no run needs the legacy
/// pipeline.
const _engine = ['android:androidManifest', 'android:buildGradle'];

void main() {
  late CliFixture project;

  setUp(() => project = CliFixture());
  tearDown(() => project.dispose());

  /// The warnings that mention [text].
  Iterable<String> warned(String text) =>
      project.logger.warnings.where((warning) => warning.contains(text));

  group('-f', () {
    test('is --yes, and warns that 4.0 removes it', () async {
      final code = await project.run(['-f', ..._engine]);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.questions, isEmpty);
      expect(project.exists('android/app/flavorizr.gradle'), isTrue);
      expect(warned('--force'), hasLength(1));
      expect(warned('--force').single, contains('4.0'));
      expect(warned('--force').single, contains('--yes'));
    });

    test('--force is the same as -f', () async {
      final code = await project.run(['apply', '--force', ..._engine]);

      expect(code, ExitCodes.ok);
      expect(project.questions, isEmpty);
      expect(warned('--force'), hasLength(1));
    });

    test('with --yes warns once and does not ask', () async {
      final code = await project.run(['-f', '-y', ..._engine]);

      expect(code, ExitCodes.ok);
      expect(project.questions, isEmpty);
      expect(warned('--force'), hasLength(1));
    });

    test('--yes alone does not warn', () async {
      final code = await project.run(['--yes', ..._engine]);

      expect(code, ExitCodes.ok);
      expect(project.logger.warnings, isEmpty);
    });

    test('warns on stderr: it is a warning, not an error', () async {
      await project.run(['-f', ..._engine]);

      expect(project.logger.warnings, isNotEmpty);
      expect(project.logger.errors, isEmpty);
    });

    test('does not change the exit code of a run that fails', () async {
      project.write('flavorizr.yaml', 'flavors: nope\n');

      final code = await project.run(['-f', ..._engine]);

      expect(code, ExitCodes.data);
      expect(warned('--force'), hasLength(1));
    });
  });

  group('-p', () {
    test('names the targets, and warns that 4.0 removes it', () async {
      final code = await project.run(['-y', '-p', 'android:flavorizrGradle']);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.exists('android/app/flavorizr.gradle'), isTrue);
      expect(
        project.read('android/app/build.gradle'),
        isNot(contains('flavorizr.gradle')),
      );
      expect(project.legacy.ran, isEmpty);
      expect(warned('--processors'), hasLength(1));
      expect(warned('--processors').single, contains('4.0'));
      expect(
        warned('--processors').single,
        contains('apply android:flavorizrGradle'),
      );
    });

    test('takes a list separated by commas, with spaces around', () async {
      final code = await project.run([
        '-y',
        '--processors',
        'android:androidManifest, android:buildGradle',
      ]);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.exists('android/app/flavorizr.gradle'), isTrue);
      expect(
        project.read('android/app/build.gradle'),
        contains('flavorizr.gradle'),
      );
      expect(project.logger.output, isNot(contains('android:icons')));
    });

    test('may be repeated', () async {
      final code = await project.run([
        '-y',
        '-p',
        'android:flavorizrGradle',
        '-p',
        'android:buildGradle',
      ]);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(warned('--processors'), hasLength(1));
      expect(
        project.read('android/app/build.gradle'),
        contains('flavorizr.gradle'),
      );
    });

    test('adds to the positional targets', () async {
      final code = await project.run([
        '-y',
        'android:flavorizrGradle',
        '-p',
        'android:buildGradle',
      ]);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.exists('android/app/flavorizr.gradle'), isTrue);
      expect(
        project.read('android/app/build.gradle'),
        contains('flavorizr.gradle'),
      );
      expect(project.logger.output, isNot(contains('android:icons')));
    });

    test('the same target twice runs it once', () async {
      final code = await project.run([
        '-y',
        'android:buildGradle',
        '-p',
        'android:buildGradle',
      ]);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(
        RegExp(
          r'^\s+\d+\. android:buildGradle',
          multiLine: true,
        ).allMatches(project.logger.output),
        hasLength(1),
      );
    });

    test('suggests the positional targets too', () async {
      await project.run(['-y', 'android:icons', '-p', 'android:buildGradle']);

      expect(
        warned('--processors').single,
        contains('apply android:icons android:buildGradle'),
      );
    });

    test('is accepted by plan and status, and warns', () async {
      final before = project.snapshot();

      final plan = await project.run(['plan', '-p', 'android:flavorizrGradle']);
      final status = await project.run([
        'status',
        '-p',
        'android:flavorizrGradle',
      ]);

      expect(plan, ExitCodes.ok, reason: project.logger.output);
      expect(status, ExitCodes.attention, reason: project.logger.output);
      expect(warned('--processors'), hasLength(2));
      expect(project.snapshot(), before);
    });

    test('an unknown id is still a usage error, after the warning', () async {
      final code = await project.run(['-p', 'android:nope']);

      expect(code, ExitCodes.usage);
      expect(warned('--processors'), hasLength(1));
      expect(project.legacy.ran, isEmpty);
    });

    test('a command name is an unknown target, not the command', () async {
      final code = await project.run(['-p', 'list']);

      expect(code, ExitCodes.usage);
      expect(project.legacy.ran, isEmpty);
      expect(project.logger.output, isNot(contains('Recipes')));
    });

    test('with no value is a usage error', () async {
      final code = await project.run(['-y', '-p']);

      expect(code, ExitCodes.usage);
      expect(project.legacy.ran, isEmpty);
    });

    test('an empty value is as if -p was not given', () async {
      final explicit = CliFixture();
      addTearDown(explicit.dispose);

      final code = await project.run(['-y', '-p', '']);
      final without = await explicit.run(['-y']);

      expect(code, without);
      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.legacy.ids, explicit.legacy.ids);
      expect(project.snapshot(), explicit.snapshot());
      expect(warned('--processors'), hasLength(1));
    });

    test('commas with nothing between them are ignored', () async {
      final code = await project.run(['-y', '-p', ',android:buildGradle,,']);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.legacy.ran, isEmpty);
    });
  });

  group('the ids 3.0 removed', () {
    const reason = '#527';

    test(
      'are dropped with a warning that says why, and the rest runs',
      () async {
        final code = await project.run([
          '-f',
          '-p',
          'assets:download,android:buildGradle',
        ]);

        expect(code, ExitCodes.ok, reason: project.logger.output);
        expect(project.questions, isEmpty);
        expect(project.legacy.ran, isEmpty);
        expect(project.exists('android/app/flavorizr.gradle'), isTrue);
        expect(warned('assets:download'), hasLength(1));
        expect(warned('assets:download').single, contains(reason));
        expect(warned('--force'), hasLength(1));
        expect(warned('--processors'), hasLength(1));
        expect(project.logger.errors, isEmpty);
      },
    );

    for (final id in ['assets:download', 'assets:extract', 'assets:clean']) {
      test('$id is one of them', () async {
        final code = await project.run(['-y', '-p', id, 'android:buildGradle']);

        expect(code, ExitCodes.ok, reason: project.logger.output);
        expect(warned(id), hasLength(1));
        expect(project.legacy.ran, isEmpty);
      });
    }

    test(
      'alone leave nothing to run, which is not the default recipe',
      () async {
        final before = project.snapshot();

        final code = await project.run([
          '-f',
          '-p',
          'assets:download,assets:extract,assets:clean',
        ]);

        expect(code, ExitCodes.ok, reason: project.logger.output);
        expect(project.snapshot(), before);
        expect(project.legacy.ran, isEmpty);
        expect(project.logger.output, contains('There is nothing to run.'));
        expect(warned('assets:download'), hasLength(1));
        expect(warned('assets:extract'), hasLength(1));
        expect(warned('assets:clean'), hasLength(1));
      },
    );

    test('alone leave the positional targets to run', () async {
      final code = await project.run([
        '-y',
        'android:flavorizrGradle',
        '-p',
        'assets:download',
      ]);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.exists('android/app/flavorizr.gradle'), isTrue);
      expect(project.logger.output, isNot(contains('nothing to run')));
    });

    test('as a positional target are not dropped: they are unknown', () async {
      // Only the 2.x option is forgiving: a target of 3.0 is what it says.
      final code = await project.run(['-y', 'assets:download']);

      expect(warned('assets:download'), isEmpty);
      expect(code, ExitCodes.usage);
      expect(project.logger.errors.join(), contains('assets:download'));
    });
  });
}
