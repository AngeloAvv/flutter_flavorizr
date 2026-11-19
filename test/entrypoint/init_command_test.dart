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
import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:test/test.dart';

import 'cli_fixture.dart';

const _freshMain = '''
import 'package:flutter/material.dart';

void main() => runApp(const MyApp());

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox();
}
''';

void main() {
  late CliFixture project;

  setUp(() {
    project = CliFixture();
    File(project.abs('flavorizr.yaml')).deleteSync();
  });
  tearDown(() => project.dispose());

  FlavorizrConfig written() =>
      FlavorizrConfig.parse(project.read('flavorizr.yaml'));

  group('flavorizr init', () {
    test(
      'with --yes writes the defaults for the platforms the project has',
      () async {
        final code = await project.run(['init', '--yes']);

        expect(code, ExitCodes.ok, reason: project.logger.output);
        expect(project.prompts, isEmpty);

        final config = written();

        expect(config.androidFlavors.keys, ['dev', 'prod']);
        expect(
          config.androidFlavors['dev']!.android!.applicationId,
          'com.example.app.dev',
        );
        expect(config.androidFlavors['dev']!.app.name, 'App Dev');
        expect(config.iosFlavorsAvailable, isFalse);
        expect(project.read('flavorizr.yaml'), isNot(contains('recipes')));
        expect(project.logger.output, contains('flavorizr plan'));
      },
    );

    test('what it writes is what plan and apply run on', () async {
      await project.run(['init', '--yes', '--flavors', 'apple,banana']);

      expect(
        await project.run(['plan']),
        ExitCodes.ok,
        reason: project.logger.output,
      );
      expect(
        await project.run(['apply', '--yes', ...engineTargets]),
        ExitCodes.ok,
        reason: project.logger.output,
      );
      expect(await project.run(['status']), ExitCodes.ok);
    });

    test('writes a flavor for every platform folder the project has', () async {
      for (final platform in ['ios', 'macos', 'linux', 'windows']) {
        Directory(project.abs(platform)).createSync();
      }

      await project.run([
        'init',
        '--flavors',
        'dev, prod',
        '--id',
        'com.acme.shop',
      ]);

      final config = written();
      final dev = config.flavors['dev']!;

      expect(dev.android!.applicationId, 'com.acme.shop.dev');
      expect(dev.ios!.bundleId, 'com.acme.shop.dev');
      expect(dev.macos!.bundleId, 'com.acme.shop.dev');
      expect(dev.linux!.applicationId, 'com.acme.shop.dev');
      expect(dev.windows, isNotNull);
      expect(config.flavors.keys, ['dev', 'prod']);
    });

    test('asks for what the options leave out, with a default', () async {
      project.answers.addAll({
        'Flavors': 'qa,live',
        'Application id': 'org.acme.app',
        'Name of the app of qa': 'Acme "QA"',
      });

      final code = await project.run(['init']);
      final config = written();

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.prompts, [
        'Flavors',
        'Application id',
        'Name of the app of qa',
        'Name of the app of live',
      ]);
      expect(config.flavors.keys, ['qa', 'live']);
      expect(config.flavors['qa']!.android!.applicationId, 'org.acme.app.qa');
      expect(config.flavors['qa']!.app.name, 'Acme "QA"');
      expect(config.flavors['live']!.app.name, 'App Live');
    });

    test(
      'names the application after the project, without underscores',
      () async {
        project.write('pubspec.yaml', 'name: my_shop_app\n');

        await project.run(['init', '--yes']);

        final dev = written().flavors['dev']!;

        expect(dev.android!.applicationId, 'com.example.myshopapp.dev');
        expect(dev.app.name, 'My Shop App Dev');
      },
    );

    test('reads the name of the project as yaml, quoted or not', () async {
      project.write('pubspec.yaml', 'name: "my_shop_app"\n');

      await project.run(['init', '--yes']);

      expect(written().flavors['dev']!.app.name, 'My Shop App Dev');
    });

    test('a flavor that is a word of yaml is a flavor, quoted', () async {
      final code = await project.run(['init', '--yes', '--flavors', 'yes,off']);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(written().flavors.keys, ['yes', 'off']);
    });

    test('leaves nothing behind when the file cannot be written', () async {
      // A directory in its place: it cannot be created as a file.
      Directory(project.abs('flavorizr.yaml')).createSync();

      final code = await project.run(['init', '--yes', '--force']);

      expect(code, isNot(ExitCodes.ok));
      expect(
        FileSystemEntity.isDirectorySync(project.abs('flavorizr.yaml')),
        isTrue,
      );
    });

    test(
      'a failure that is not a file that exists is reported as it is',
      () async {
        Directory(project.abs('flavorizr.yaml')).createSync();

        final code = await project.run(['init', '--yes']);

        expect(code, ExitCodes.software);
        expect(project.logger.errors.join(), isNot(contains('meanwhile')));
      },
    );

    test('--force replaces what appeared while it asked', () async {
      project.whileAsking = (_) => project.write('flavorizr.yaml', 'mine');

      final code = await project.run(['init', '--force']);

      expect(code, ExitCodes.ok);
      expect(project.read('flavorizr.yaml'), contains('flavors:'));
    });

    test('a flavor named like a command is a flavor', () async {
      final code = await project.run([
        '--flavors',
        'plan,list',
        'init',
        '--yes',
      ]);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(written().flavors.keys, ['plan', 'list']);
    });

    group('refuses, and writes nothing', () {
      for (final (args, reason) in [
        (['--flavors', 'Dev'], 'a flavor that starts with a capital'),
        (['--flavors', 'my-flavor'], 'a flavor with a hyphen'),
        (['--flavors', 'a,a'], 'a flavor twice'),
        (['--flavors', ','], 'no flavor'),
        (['--flavors', 'class'], 'a flavor that is a word of Dart'),
        (
          ['--flavors', 'New'],
          'a flavor that is a word of Dart, in other case',
        ),
        (['--flavors', 'index'], 'a flavor that is a member of every enum'),
        (['--flavors', 'main'], 'a flavor Gradle takes for a source set'),
        (['--flavors', 'release'], 'a flavor Gradle takes for a build type'),
        (['--flavors', 'testing'], 'a flavor that starts like the tests'),
        (
          ['--flavors', 'androidTestX'],
          'a flavor that starts like the Android tests',
        ),
        (['--flavors', 'qa,qA'], 'two flavors the Flutter code names the same'),
        (['--id', 'app'], 'an identifier that is not a reverse domain name'),
        (['--id', 'com.my_app'], 'an identifier with an underscore'),
      ]) {
        test(reason, () async {
          final code = await project.run(['init', '--yes', ...args]);

          expect(code, ExitCodes.usage);
          expect(project.exists('flavorizr.yaml'), isFalse);
          expect(project.logger.errors, isNotEmpty);
        });
      }

      test(
        'a project that has a flavorizr.yaml, unless it is forced',
        () async {
          project.write('flavorizr.yaml', 'old');

          expect(await project.run(['init', '--yes']), ExitCodes.attention);
          expect(project.read('flavorizr.yaml'), 'old');
          expect(project.logger.errors.join(), contains('--force'));

          expect(await project.run(['init', '--yes', '--force']), ExitCodes.ok);
          expect(project.read('flavorizr.yaml'), contains('flavors:'));
        },
      );

      test('a folder that is not a project', () async {
        File(project.abs('pubspec.yaml')).deleteSync();

        expect(await project.run(['init', '--yes']), ExitCodes.usage);
        expect(project.exists('flavorizr.yaml'), isFalse);
      });

      test('a project with no platform folder', () async {
        Directory(project.abs('android')).deleteSync(recursive: true);

        expect(await project.run(['init', '--yes']), ExitCodes.usage);
        expect(project.logger.errors.join(), contains('No platform folder'));
      });
    });

    group('flutter:scaffold', () {
      setUp(() => project.write('lib/main.dart', _freshMain));

      test('is offered on a new project, and added when accepted', () async {
        project.answer = true;

        await project.run(['init', '--flavors', 'dev,prod']);

        expect(project.questions.single, contains('flutter:scaffold'));
        expect(written().defaultRecipe, 'start');
        expect(written().recipes!['start'], ['all', 'flutter:scaffold']);
      });

      test(
        'says that apply keeps the files that exist, and how to replace them',
        () async {
          project.answer = true;

          await project.run(['init', '--flavors', 'dev']);

          expect(project.logger.output, contains('--overwrite-scaffold'));

          project.answer = false;
          await project.run(['init', '--flavors', 'dev', '--force']);

          expect(
            project.logger.lines.where(
              (l) => l.contains('--overwrite-scaffold'),
            ),
            hasLength(1),
          );
        },
      );

      test('is not added when declined', () async {
        project.answer = false;

        await project.run(['init', '--flavors', 'dev,prod']);

        expect(project.read('flavorizr.yaml'), isNot(contains('recipes')));
      });

      test('is not offered on a project that has been changed', () async {
        project.write('lib/main.dart', 'void main() {}');

        await project.run(['init', '--flavors', 'dev,prod']);

        expect(project.questions, isEmpty);
      });

      test('is not offered with --yes, and is added with --scaffold', () async {
        await project.run(['init', '--yes']);

        expect(project.questions, isEmpty);
        expect(project.read('flavorizr.yaml'), isNot(contains('recipes')));

        await project.run(['init', '--yes', '--force', '--scaffold']);

        expect(written().defaultRecipe, 'start');
      });

      test('--no-scaffold skips the question', () async {
        await project.run(['init', '--flavors', 'dev', '--no-scaffold']);

        expect(project.questions, isEmpty);
        expect(project.read('flavorizr.yaml'), isNot(contains('recipes')));
      });
    });
  });

  test('a project with no configuration is told about init', () async {
    final code = await project.run(['plan']);

    expect(code, isNot(ExitCodes.ok));
    expect(project.logger.errors.join(), contains('flavorizr init'));
  });
}
