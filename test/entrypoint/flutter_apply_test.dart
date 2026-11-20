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

import 'package:flutter_flavorizr/src/engine/shadow/file_digest.dart';
import 'package:flutter_flavorizr/src/entrypoint/exit_codes.dart';
import 'package:test/test.dart';

import 'cli_fixture.dart';

/// The `lib/main.dart` `flutter create` writes.
const _counterMain = '''
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}
''';

const _scaffold = [
  'lib/flavors.dart',
  'lib/flavors.g.dart',
  'lib/app.dart',
  'lib/pages/my_home_page.dart',
  'lib/main.dart',
];

void main() {
  late CliFixture project;

  setUp(() {
    project = CliFixture();
    project.write('lib/main.dart', _counterMain);
  });
  tearDown(() => project.dispose());

  group('apply flutter:flavors', () {
    test(
      'writes flavors.g.dart, managed, and flavors.dart, scaffold',
      () async {
        final code = await project.run(['apply', '--yes', 'flutter:flavors']);

        expect(code, ExitCodes.ok, reason: project.logger.output);
        expect(project.read('lib/flavors.g.dart'), contains('enum Flavor {'));
        expect(
          project.read('lib/flavors.dart'),
          contains("export 'flavors.g.dart';"),
        );

        final lock = project.read('flavorizr.lock');

        expect(lock, contains('flutter:flavors:'));
        expect(lock, contains('lib/flavors.g.dart:\n        hash: sha256:'));
        expect(lock, contains('ownership: managed'));
        // What flavorizr wrote is hashed, so that it can be removed safely.
        expect(lock, contains('lib/flavors.dart:\n        hash: sha256:'));
        expect(lock, contains('ownership: scaffold'));
        expect(
          lock,
          contains(
            'hash: ${digestOf(utf8.encode(project.read('lib/flavors.dart')))}\n'
            '        ownership: scaffold',
          ),
        );
      },
    );

    test(
      'never writes main.dart, app.dart or pages/, whatever the run',
      () async {
        // The default recipe, which 2.x ran with the files of a new app.
        final code = await project.run(['apply', '--yes']);

        expect(code, ExitCodes.ok, reason: project.logger.output);
        expect(project.read('lib/main.dart'), _counterMain);
        expect(project.exists('lib/app.dart'), isFalse);
        expect(project.exists('lib/pages'), isFalse);
        expect(project.exists('lib/flavors.g.dart'), isTrue);
      },
    );

    test('is part of a full run, which records the flavors', () async {
      await project.run(['apply', '--yes']);

      expect(project.read('flavorizr.lock'), contains('apple: sha256:'));
    });

    test('keeps a flavors.dart of the user, and 2.x projects theirs', () async {
      project.write('lib/flavors.dart', 'enum Flavor { apple }\n');

      final code = await project.run(['apply', '--yes', 'flutter:flavors']);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.read('lib/flavors.dart'), 'enum Flavor { apple }\n');
      expect(project.exists('lib/flavors.g.dart'), isTrue);
    });

    test(
      'follows the flavors of flavorizr.yaml, and not flavors.dart',
      () async {
        await project.run(['apply', '--yes', 'flutter:flavors']);
        project.write(
          'lib/flavors.dart',
          '// mine\nexport "flavors.g.dart";\n',
        );
        project.write('flavorizr.yaml', CliFixture.config(['apple', 'cherry']));

        final code = await project.run(['apply', '--yes', 'flutter:flavors']);

        expect(code, ExitCodes.ok, reason: project.logger.output);
        expect(
          project.read('lib/flavors.g.dart'),
          contains("cherry('cherry')"),
        );
        expect(project.read('lib/flavors.g.dart'), isNot(contains('banana')));
        expect(project.read('lib/flavors.dart'), startsWith('// mine'));
      },
    );

    test('a second run has nothing to do, and status agrees', () async {
      await project.run(['apply', '--yes', ...engineTargets]);
      final before = project.snapshot();

      expect(
        await project.run(['apply', '--yes', ...engineTargets]),
        ExitCodes.ok,
      );
      expect(project.snapshot(), before);

      final code = await project.run(['status', ...engineTargets]);

      expect(code, ExitCodes.ok, reason: project.logger.output);
    });

    test('a hand edit of flavors.g.dart is a conflict, and drift', () async {
      await project.run(['apply', '--yes', ...engineTargets]);
      final generated = project.read('lib/flavors.g.dart');
      project.write('lib/flavors.g.dart', '// edited\n$generated');

      expect(
        await project.run(['status', ...engineTargets]),
        ExitCodes.attention,
      );

      project.write('flavorizr.yaml', CliFixture.config(['apple', 'cherry']));

      expect(
        await project.run(['apply', '--yes', ...engineTargets]),
        ExitCodes.attention,
        reason: project.logger.output,
      );
      expect(project.read('lib/flavors.g.dart'), startsWith('// edited'));

      expect(
        await project.run([
          'apply',
          '--yes',
          '--on-conflict=overwrite',
          ...engineTargets,
        ]),
        ExitCodes.ok,
      );
      expect(project.read('lib/flavors.g.dart'), contains("cherry('cherry')"));
    });

    test('says so when the flavors.dart that is kept does not export '
        'flavors.g.dart', () async {
      project.write('lib/flavors.dart', 'enum Flavor { apple }\n');

      await project.run(['apply', '--yes', 'flutter:flavors']);

      expect(project.logger.warnings, hasLength(1));
      expect(project.logger.warnings.single, contains('lib/flavors.dart'));
      expect(project.logger.warnings.single, contains('flavors.g.dart'));
      // The main.dart of 2.x assigns F.appFlavor, which the generated F, a
      // getter, does not allow: apply does not touch main.dart, so say so.
      expect(project.logger.warnings.single, contains('F.appFlavor'));
      expect(project.logger.warnings.single, contains('lib/main.dart'));

      project.write('lib/flavors.dart', "export 'flavors.g.dart';\n");
      project.logger.warnings.clear();

      await project.run(['apply', '--yes', 'flutter:flavors']);

      expect(project.logger.warnings, isEmpty);
    });

    test('a hand edit of flavors.dart is not drift', () async {
      await project.run(['apply', '--yes', ...engineTargets]);
      project.write('lib/flavors.dart', '// mine\n');

      expect(await project.run(['status', ...engineTargets]), ExitCodes.ok);
    });
  });

  group('apply flutter:scaffold', () {
    test('adds the files of a new app, with the flavors they need', () async {
      final code = await project.run(['apply', '--yes', 'flutter:scaffold']);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.logger.output, contains('flutter:flavors (auto)'));

      for (final path in _scaffold.where((path) => path != 'lib/main.dart')) {
        expect(project.exists(path), isTrue, reason: path);
      }
    });

    test('never overwrites the main.dart that exists', () async {
      final code = await project.run(['apply', '--yes', 'flutter:scaffold']);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.read('lib/main.dart'), _counterMain);
    });

    test('--overwrite-scaffold replaces the main.dart of a fresh project, and '
        'shows it first', () async {
      final code = await project.run([
        'apply',
        '--yes',
        '--overwrite-scaffold',
        'flutter:scaffold',
      ]);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.logger.output, contains('~ lib/main.dart (scaffold)'));
      expect(project.read('lib/main.dart'), contains('runApp(const App());'));
      for (final path in _scaffold) {
        expect(project.exists(path), isTrue, reason: path);
      }
    });

    test('is not part of `all`, `flutter` or the default run', () async {
      for (final target in [
        <String>[],
        ['all'],
        ['flutter'],
      ]) {
        final fresh = CliFixture();
        addTearDown(fresh.dispose);

        await fresh.run(['apply', '--yes', ...target]);

        expect(fresh.exists('lib/main.dart'), isFalse, reason: '$target');
        expect(fresh.exists('lib/app.dart'), isFalse, reason: '$target');
      }
    });

    test('a file the user edited stays theirs on the next run', () async {
      const everything = [...engineTargets, 'flutter:scaffold'];

      await project.run([
        'apply',
        '--yes',
        '--overwrite-scaffold',
        ...everything,
      ]);
      project.write('lib/main.dart', '// mine\n');
      project.write('lib/app.dart', '// mine too\n');

      final code = await project.run(['apply', '--yes', ...everything]);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.read('lib/main.dart'), '// mine\n');
      expect(project.read('lib/app.dart'), '// mine too\n');
      expect(await project.run(['status', ...everything]), ExitCodes.ok);
    });

    test(
      'plan --overwrite-scaffold shows the replacement and writes nothing',
      () async {
        final before = project.snapshot();

        final code = await project.run([
          'plan',
          '--overwrite-scaffold',
          'flutter:scaffold',
        ]);

        expect(code, ExitCodes.ok, reason: project.logger.output);
        expect(project.logger.output, contains('~ lib/main.dart (scaffold)'));
        expect(project.snapshot(), before);

        project.logger.lines.clear();
        await project.run(['plan', 'flutter:scaffold']);

        expect(project.logger.output, isNot(contains('~ lib/main.dart')));
      },
    );

    test('--overwrite-scaffold is the only way to replace what the user '
        'edited', () async {
      await project.run(['apply', '--yes', 'flutter:scaffold']);
      project.write('lib/app.dart', '// mine\n');

      await project.run([
        'apply',
        '--yes',
        '--overwrite-scaffold',
        'flutter:app',
      ]);

      expect(project.read('lib/app.dart'), contains('class App'));
    });

    test('--overwrite-scaffold also replaces flavors.dart, which the recipe '
        'pulls in', () async {
      await project.run(['apply', '--yes', 'flutter:scaffold']);
      project.write('lib/flavors.dart', '// mine\n');

      await project.run(['apply', '--yes', 'flutter:scaffold']);

      expect(project.read('lib/flavors.dart'), '// mine\n');

      await project.run([
        'apply',
        '--yes',
        '--overwrite-scaffold',
        'flutter:scaffold',
      ]);

      expect(
        project.read('lib/flavors.dart'),
        contains("export 'flavors.g.dart'"),
      );
    });

    group('the hash of what it wrote', () {
      String hashIn(String path) =>
          'hash: ${digestOf(utf8.encode(project.read(path)))}\n'
          '        ownership: scaffold';

      test('is in the lock for the files it created, and not for the '
          'main.dart that was there', () async {
        await project.run(['apply', '--yes', 'flutter:scaffold']);

        final lock = project.read('flavorizr.lock');

        for (final path in ['lib/app.dart', 'lib/pages/my_home_page.dart']) {
          expect(
            lock,
            contains('$path:\n        ${hashIn(path)}'),
            reason: path,
          );
        }
        expect(lock, contains('lib/main.dart:\n        ownership: scaffold'));
      });

      test('stays what was written when the user edits the file, so that '
          'the edit is told from it', () async {
        await project.run(['apply', '--yes', 'flutter:scaffold']);

        final written = hashIn('lib/app.dart');

        project.write('lib/app.dart', '// mine\n');

        expect(
          await project.run(['apply', '--yes', 'flutter:scaffold']),
          ExitCodes.ok,
          reason: project.logger.output,
        );
        expect(project.read('lib/app.dart'), '// mine\n');
        expect(project.read('flavorizr.lock'), contains(written));
      });

      test('is the one of the new content when --overwrite-scaffold '
          'replaces the file', () async {
        await project.run(['apply', '--yes', 'flutter:scaffold']);
        project.write('lib/app.dart', '// mine\n');

        await project.run([
          'apply',
          '--yes',
          '--overwrite-scaffold',
          'flutter:scaffold',
        ]);

        expect(project.read('lib/app.dart'), contains('class App'));
        expect(
          project.read('flavorizr.lock'),
          contains(hashIn('lib/app.dart')),
        );
      });

      test('is learned by a lock that has none, for a file that is as '
          'flavorizr writes it, and not for one the user changed', () async {
        await project.run(['apply', '--yes', 'flutter:scaffold']);

        final lock = project.read('flavorizr.lock');
        final appHash = hashIn('lib/app.dart');
        final pageHash = hashIn('lib/pages/my_home_page.dart');

        // A lock of version 1 has no hash for a scaffold.
        project.write(
          'flavorizr.lock',
          lock
              .replaceAll(
                RegExp(r'hash: sha256:[0-9a-f]+\n        ownership: scaffold'),
                'ownership: scaffold',
              )
              .replaceFirst('schemaVersion: 2', 'schemaVersion: 1'),
        );
        project.write('lib/pages/my_home_page.dart', '// mine\n');

        final code = await project.run(['apply', '--yes', 'flutter:scaffold']);

        expect(code, ExitCodes.ok, reason: project.logger.output);
        expect(project.read('flavorizr.lock'), contains(appHash));
        expect(project.read('flavorizr.lock'), isNot(contains(pageHash)));
        expect(project.read('flavorizr.lock'), contains('schemaVersion: 2'));
        expect(project.read('lib/pages/my_home_page.dart'), '// mine\n');
      });
    });

    test('running only flutter:main brings what it needs', () async {
      await project.run(['apply', '--yes', 'flutter:main']);

      expect(project.logger.output, contains('flutter:app (auto)'));
      expect(project.exists('lib/pages/my_home_page.dart'), isTrue);
      expect(project.exists('lib/flavors.g.dart'), isTrue);
    });
  });

  group('list', () {
    test('shows the flutter processors on the engine and the recipe', () async {
      await project.run(['list']);

      expect(project.logger.output, contains('flutter:flavors [engine]'));
      expect(project.logger.output, contains('flutter:main [engine]'));
      expect(project.logger.output, contains('flutter:scaffold (built-in)'));
    });
  });
}
