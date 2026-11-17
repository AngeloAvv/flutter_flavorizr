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

import 'dart:convert';
import 'dart:io';

import 'package:flutter_flavorizr/src/entrypoint/exit_codes.dart';
import 'package:flutter_test/flutter_test.dart';

import 'cli_fixture.dart';
import 'output/json_schema_validator.dart';

final _schema =
    jsonDecode(
          File('doc/schemas/flavorizr-output.schema.json').readAsStringSync(),
        )
        as Map<String, Object?>;

final _ansi = RegExp('\x1B');

void main() {
  late CliFixture project;

  setUp(() => project = CliFixture());
  tearDown(() => project.dispose());

  /// The document `--json` printed, which must be the only thing on stdout and
  /// must hold to the schema.
  Map<String, Object?> document() {
    final stdout = project.stdout.toString();

    expect(stdout.trimRight().split('\n'), hasLength(1), reason: stdout);

    final doc = jsonDecode(stdout) as Map<String, Object?>;

    expect(validateJson(doc, _schema), isEmpty, reason: stdout);

    return doc;
  }

  List<Map<String, Object?>> changes(Map<String, Object?> doc) =>
      (doc['changes'] as List).cast<Map<String, Object?>>();

  group('--json', () {
    group('plan', () {
      test('prints the processors, the flavors and the changes', () async {
        final code = await project.run(['plan', '--json', ...engineTargets]);
        final doc = document();

        expect(code, ExitCodes.ok);
        expect(doc['command'], 'plan');
        expect(doc['exitCode'], 0);
        expect(doc['schemaVersion'], 1);
        expect(
          (doc['processors'] as List).map((p) => (p as Map)['id']),
          contains('android:flavorizrGradle'),
        );
        expect(
          (doc['processors'] as List).firstWhere(
            (p) => (p as Map)['id'] == 'android:flavorizrGradle',
          ),
          {
            'id': 'android:flavorizrGradle',
            'platform': 'android',
            'runsOn': 'engine',
            'auto': true,
          },
        );
        expect(doc['flavors'], {
          'added': ['apple', 'banana'],
          'removed': <String>[],
          'changed': <String>[],
        });
        expect(
          changes(doc),
          anyElement(
            equals({
              'path': 'android/app/flavorizr.gradle',
              'platform': 'android',
              'change': 'added',
              'disposition': 'apply',
              'ownership': 'managed',
            }),
          ),
        );
        expect(doc['summary'], {
          'added': 1,
          'modified': 2,
          'deleted': 0,
          'conflicts': 0,
        });
        expect(doc['warnings'], isEmpty);
        expect(doc['errors'], isEmpty);
      });

      test('prints nothing else, and writes nothing', () async {
        final before = project.snapshot();

        await project.run(['plan', '--json', ...engineTargets]);

        expect(project.logger.lines, isEmpty);
        expect(project.snapshot(), before);
      });

      test('marks the processors that are not on the engine', () async {
        await project.run([
          'plan',
          '--json',
          ...engineTargets,
          'flutter:flavors',
        ]);

        expect((document()['processors'] as List).last, {
          'id': 'flutter:flavors',
          'platform': 'flutter',
          'runsOn': 'legacy',
          'auto': false,
        });
      });

      test('exits with 1 and says which files are in the way', () async {
        await project.run(['apply', '-y', ...engineTargets]);
        project.write('android/app/flavorizr.gradle', '// mine\n');
        project.write('flavorizr.yaml', CliFixture.config(['apple', 'pear']));
        project.stdout.clear();

        final code = await project.run(['plan', '--json', ...engineTargets]);
        final doc = document();

        expect(code, ExitCodes.attention);
        expect(doc['exitCode'], 1);
        expect((doc['summary'] as Map)['conflicts'], 1);
        expect(
          changes(doc).where((c) => c['disposition'] == 'conflict').single,
          containsPair('path', 'android/app/flavorizr.gradle'),
        );
      });

      test('has an empty plan when nothing is to run', () async {
        project.write(
          'flavorizr.yaml',
          '${CliFixture.config(['a'])}instructions: []\n',
        );

        final code = await project.run(['plan', '--json']);
        final doc = document();

        expect(code, ExitCodes.ok);
        expect(doc['processors'], isEmpty);
        expect(changes(doc), isEmpty);
      });
    });

    group('a failure', () {
      test(
        'is a document with the exit code, and the error on stderr too',
        () async {
          final code = await project.run(['plan', '--json', 'nope']);
          final doc = document();

          expect(code, ExitCodes.usage);
          expect(doc['exitCode'], 64);
          expect(doc['errors'], hasLength(1));
          expect(project.logger.errors, doc['errors']);
          expect(doc.containsKey('changes'), isFalse);
        },
      );

      test('of a configuration is 65', () async {
        project.write('flavorizr.yaml', 'flavors: nope\n');

        final code = await project.run(['plan', '--json', ...engineTargets]);

        expect(code, ExitCodes.data);
        expect(document()['exitCode'], 65);
      });

      test('of a refusal keeps its message', () async {
        await project.run(['apply', '-y', ...engineTargets]);
        project.write('flavorizr.yaml', 'flavors: {}\n');
        project.stdout.clear();

        final code = await project.run(['plan', '--json', ...engineTargets]);
        final doc = document();

        expect(code, ExitCodes.data);
        expect((doc['errors'] as List).single, contains('flavor'));
        expect(project.logger.errors, doc['errors']);
      });

      test('of a processor is 70', () async {
        File(
          project.abs('android/app/src/main/AndroidManifest.xml'),
        ).deleteSync();

        final code = await project.run([
          'plan',
          '--json',
          'android:androidManifest',
        ]);
        final doc = document();

        expect(code, ExitCodes.software);
        expect(doc['exitCode'], 70);
        expect(doc['errors'], isNotEmpty);
      });

      test(
        'of the command line leaves stdout empty and has no usage',
        () async {
          final code = await project.run(['plan', '--json', '--nope']);

          expect(code, ExitCodes.usage);
          expect(project.stdout.toString(), isEmpty);
          expect(project.logger.errors, hasLength(1));
          expect(project.logger.output, isNot(contains('Usage')));
        },
      );

      test('--json is not an option of doctor', () async {
        final code = await project.run(['doctor', '--json']);

        expect(code, ExitCodes.usage);
        expect(project.stdout.toString(), isEmpty);
      });
    });

    group('apply', () {
      test('applies without asking, and says what ran', () async {
        final code = await project.run(['apply', '--json', ...engineTargets]);
        final doc = document();

        expect(code, ExitCodes.ok, reason: project.logger.output);
        expect(project.questions, isEmpty);
        expect(project.exists('flavorizr.lock'), isTrue);
        expect(doc['command'], 'apply');
        expect(doc['applied'], isTrue);
        expect(doc['cancelled'], isFalse);
        expect(
          (doc['steps'] as List).map((s) => (s as Map)['id']),
          containsAll(engineTargets),
        );
        expect(
          (doc['steps'] as List).map((s) => (s as Map)['status']).toSet(),
          {'completed'},
        );
        expect(
          (doc['steps'] as List).every((s) => (s as Map)['durationMs'] is int),
          isTrue,
        );
        expect(project.logger.lines, isEmpty);
      });

      test('with --yes is the same', () async {
        final code = await project.run([
          'apply',
          '--json',
          '-y',
          ...engineTargets,
        ]);

        expect(code, ExitCodes.ok);
        expect(document()['applied'], isTrue);
      });

      test('never asks about a conflict, it fails with 1', () async {
        await project.run(['apply', '-y', ...engineTargets]);
        project.write('android/app/flavorizr.gradle', '// mine\n');
        project.write('flavorizr.yaml', CliFixture.config(['apple', 'pear']));
        project.stdout.clear();

        final code = await project.run(['apply', '--json', ...engineTargets]);
        final doc = document();

        expect(code, ExitCodes.attention);
        expect(doc['applied'], isFalse);
        expect(project.read('android/app/flavorizr.gradle'), '// mine\n');
        expect((doc['errors'] as List), isNotEmpty);
      });

      test('follows --on-conflict', () async {
        await project.run(['apply', '-y', ...engineTargets]);
        project.write('android/app/flavorizr.gradle', '// mine\n');
        project.write('flavorizr.yaml', CliFixture.config(['apple', 'pear']));
        project.stdout.clear();

        final code = await project.run([
          'apply',
          '--json',
          '--on-conflict=overwrite',
          ...engineTargets,
        ]);

        expect(code, ExitCodes.ok);
        expect(project.read('android/app/flavorizr.gradle'), contains('pear'));
      });

      group('the summary is what was written', () {
        Future<Map<String, Object?>> applyOver(String policy) async {
          await project.run(['apply', '-y', ...engineTargets]);
          project.write('android/app/flavorizr.gradle', '// mine\n');
          project.write('flavorizr.yaml', CliFixture.config(['apple', 'pear']));
          project.stdout.clear();

          final code = await project.run([
            'apply',
            '--json',
            '--on-conflict=$policy',
            ...engineTargets,
          ]);

          expect(code, ExitCodes.ok, reason: project.logger.output);

          return document();
        }

        test('an overwritten conflict is a change, not a conflict', () async {
          final doc = await applyOver('overwrite');
          final modified = changes(doc).where((c) => c['change'] == 'modified');

          expect(doc['summary'], containsPair('conflicts', 0));
          expect(
            (doc['summary'] as Map)['modified'],
            modified.length,
            reason: 'the file overwritten counts with the ones that changed',
          );
        });

        test('a kept conflict is the one that was not written', () async {
          final doc = await applyOver('keep');
          final modified = changes(doc).where((c) => c['change'] == 'modified');

          expect(doc['summary'], containsPair('conflicts', 1));
          expect((doc['summary'] as Map)['modified'], modified.length - 1);
        });
      });

      test(
        'lists the processors that are not on the engine as steps',
        () async {
          await project.run([
            'apply',
            '--json',
            ...engineTargets,
            'flutter:flavors',
          ]);

          expect((document()['steps'] as List).last, {
            'id': 'flutter:flavors',
            'status': 'completed',
            'durationMs': 1,
          });
        },
      );

      test('says the steps that were skipped when a processor fails', () async {
        File(
          project.abs('android/app/src/main/AndroidManifest.xml'),
        ).deleteSync();

        final code = await project.run(['apply', '--json', ...engineTargets]);
        final doc = document();
        final steps = (doc['steps'] as List).cast<Map<String, Object?>>();

        expect(code, ExitCodes.software);
        expect(doc['applied'], isFalse);
        expect(steps.map((s) => s['status']), contains('failed'));
        expect(steps.map((s) => s['status']), contains('skipped'));
        expect(
          steps
              .where((s) => s['status'] == 'skipped')
              .map((s) => s['durationMs']),
          everyElement(isNull),
        );
        expect(project.exists('flavorizr.lock'), isFalse);
      });

      test(
        'keeps the deprecation warnings, on stderr and in the document',
        () async {
          final code = await project.run([
            'apply',
            '--json',
            '-f',
            ...engineTargets,
          ]);
          final doc = document();

          expect(code, ExitCodes.ok);
          expect(doc['warnings'], hasLength(1));
          expect(doc['warnings'], project.logger.warnings);
          expect((doc['warnings'] as List).single, contains('--yes'));
        },
      );
    });

    group('status', () {
      test('is in sync once applied', () async {
        await project.run(['apply', '-y', ...engineTargets]);
        project.stdout.clear();

        final code = await project.run(['status', '--json', ...engineTargets]);
        final doc = document();

        expect(code, ExitCodes.ok);
        expect(doc['inSync'], isTrue);
        expect(doc['checked'], isTrue);
        expect(doc['drift'], isEmpty);
        expect(doc['summary'], {
          'added': 0,
          'modified': 0,
          'deleted': 0,
          'conflicts': 0,
        });
      });

      test('drifted: with what, and exit code 1', () async {
        final code = await project.run(['status', '--json', ...engineTargets]);
        final doc = document();
        final drift = (doc['drift'] as List).cast<Map<String, Object?>>();

        expect(code, ExitCodes.attention);
        expect(doc['inSync'], isFalse);
        expect(
          drift.map((d) => d['kind']),
          containsAll(['lock', 'flavors', 'files']),
        );
        expect(
          drift.firstWhere((d) => d['kind'] == 'files')['paths'],
          contains('android/app/flavorizr.gradle'),
        );
      });

      test('tells a hand edited file from a missing one', () async {
        await project.run(['apply', '-y', ...engineTargets]);
        project.write('android/app/flavorizr.gradle', '// mine\n');
        project.stdout.clear();

        final code = await project.run(['status', '--json', ...engineTargets]);
        final drift = (document()['drift'] as List)
            .cast<Map<String, Object?>>();

        expect(code, ExitCodes.attention);
        expect(drift.singleWhere((d) => d['kind'] == 'edited')['paths'], [
          'android/app/flavorizr.gradle',
        ]);
      });

      test('names what it did not check', () async {
        await project.run(['apply', '-y', ...engineTargets]);
        project.stdout.clear();

        await project.run([
          'status',
          '--json',
          ...engineTargets,
          'flutter:flavors',
        ]);

        expect(document()['notChecked'], ['flutter:flavors']);
      });

      test('has nothing to check without a processor of the engine', () async {
        final code = await project.run(['status', '--json', 'flutter:flavors']);
        final doc = document();

        expect(code, ExitCodes.ok);
        expect(doc['checked'], isFalse);
        expect(doc['inSync'], isTrue);
      });
    });

    group('list', () {
      test('lists the recipes and the processors', () async {
        final code = await project.run(['list', '--json']);
        final doc = document();
        final recipes = (doc['recipes'] as List).cast<Map<String, Object?>>();
        final processors = (doc['processors'] as List)
            .cast<Map<String, Object?>>();

        expect(code, ExitCodes.ok);
        expect(
          recipes.firstWhere((r) => r['name'] == 'android'),
          containsPair('builtIn', true),
        );
        expect(recipes.where((r) => r['default'] == true), hasLength(1));
        expect(
          processors.firstWhere((p) => p['id'] == 'android:icons'),
          containsPair('runsOn', 'engine'),
        );
        expect(processors.firstWhere((p) => p['id'] == 'flutter:flavors'), {
          'id': 'flutter:flavors',
          'platform': 'flutter',
          'runsOn': 'legacy',
          'needs': <String>[],
          'after': <String>[],
        });
        expect(
          (processors.firstWhere(
                (p) => p['id'] == 'android:buildGradle',
              )['needs']
              as List),
          contains('android:flavorizrGradle'),
        );
        expect(project.logger.lines, isEmpty);
      });

      test('lists the recipes of flavorizr.yaml', () async {
        project.write(
          'flavorizr.yaml',
          '${CliFixture.config(['a'])}recipes:\n  mine:\n    - android:icons\n',
        );

        await project.run(['list', '--json']);

        expect(
          ((document()['recipes'] as List).cast<Map<String, Object?>>())
              .firstWhere((r) => r['name'] == 'mine'),
          {
            'name': 'mine',
            'builtIn': false,
            'default': false,
            'members': ['android:icons'],
            'processors': ['android:icons'],
          },
        );
      });
    });

    test('has no ANSI code, not even on a terminal', () async {
      project.environment = terminal;

      await project.run(['plan', '--json', ...engineTargets]);
      await project.run(['apply', '--json', '-f', ...engineTargets]);

      expect(project.stdout.toString(), isNot(contains(_ansi)));
      expect(project.logger.output, isNot(contains(_ansi)));
    });
  });
}
