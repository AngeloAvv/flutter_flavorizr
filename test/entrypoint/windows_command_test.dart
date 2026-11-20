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
import 'package:image/image.dart' as img;
import 'package:test/test.dart';

import 'cli_fixture.dart';

const _cmake = 'windows/runner/CMakeLists.txt';
const _rc = 'windows/runner/Runner.rc';
const _main = 'windows/runner/main.cpp';
const _rcIn = 'windows/runner/Runner.rc.in';
const _mainIn = 'windows/runner/main.cpp.in';
const _templates = [_rcIn, _mainIn];

/// What a full run of a project with only Windows flavors covers: the Windows
/// recipe and the `flutter:flavors` of the `all` recipe.
const _fullRun = ['flutter:flavors', 'windows'];

String _resource(String path) =>
    File('test_resources/windows/$path').readAsStringSync();

String _config(Iterable<String> flavors) =>
    'flavors:\n${[for (final flavor in flavors) '''
  $flavor:
    app:
      name: "${flavor[0].toUpperCase()}${flavor.substring(1)} App"
    windows: {}
'''].join()}';

/// The lines of the branch of [flavor] in the region of [cmake]: from its
/// `if` to the next one.
List<String> _branch(String cmake, String flavor) {
  final lines = cmake.split('\n');
  final start = lines.indexWhere(
    (line) => line.contains('FLUTTER_APP_FLAVOR STREQUAL "$flavor"'),
  );

  expect(start, isNonNegative, reason: 'no branch for $flavor');

  final end = lines.indexWhere(
    (line) => line.trim().startsWith('elseif(') || line.trim() == 'endif()',
    start + 1,
  );

  return lines.sublist(start, end);
}

/// The icon the branch of [flavor] sets, or `null` when it sets none.
String? _icon(String cmake, String flavor) {
  final match = RegExp(
    r'set\(RUNNER_APP_ICON "([^"]+)"\)',
  ).firstMatch(_branch(cmake, flavor).join('\n'));

  return match?.group(1);
}

/// The lines of [text] outside of the marked regions.
List<String> _outsideTheRegions(String text) {
  final lines = <String>[];
  var inside = false;

  for (final line in text.split('\n')) {
    if (line.contains('BEGIN ')) inside = true;
    if (!inside) lines.add(line);
    if (line.contains('END ')) inside = false;
  }

  return lines;
}

void main() {
  late CliFixture project;
  late Map<String, String> pristine;
  late Map<String, String> templates;

  setUp(() {
    project = CliFixture(android: false);
    pristine = {
      _cmake: _resource('runner_cmake_lists_processor_test/CMakeLists.txt'),
      _rc: _resource('runner_rc_content_processor_test/Runner.rc'),
      _main: _resource('main_cpp_title_processor_test/main.cpp'),
    };
    templates = {
      _rcIn: _resource('runner_rc_content_processor_test/Runner_expected.rc'),
      _mainIn: _resource('main_cpp_title_processor_test/main_expected.cpp'),
    };
    project.write('flavorizr.yaml', _config(['apple', 'banana']));
    pristine.forEach(project.write);
  });
  tearDown(() => project.dispose());

  group('the windows processors on the engine', () {
    test('plan lists them on the engine, and writes nothing', () async {
      final before = project.snapshot();

      final code = await project.run(['plan', 'windows']);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      for (final id in [
        'windows:mainCppTemplate',
        'windows:runnerRcTemplate',
        'windows:cmake',
        'windows:dummyAssets',
        'windows:icons',
      ]) {
        expect(project.logger.output, contains(id));
      }
      expect(project.logger.output, contains('Processors on the engine'));
      expect(project.snapshot(), before);
    });

    test('apply writes the two templates, edits only the region of the '
        'CMake file and never touches Runner.rc nor main.cpp', () async {
      final code = await project.run(['apply', '--yes', ..._fullRun]);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.legacy.ids, isEmpty);

      templates.forEach(
        (path, template) => expect(project.read(path), template, reason: path),
      );
      expect(project.read(_rc), pristine[_rc]);
      expect(project.read(_main), pristine[_main]);
      expect(project.read(_cmake), isNot(pristine[_cmake]));
      expect(
        _outsideTheRegions(project.read(_cmake)),
        _outsideTheRegions(pristine[_cmake]!),
      );
      expect(project.read(_cmake), contains('"Banana App"'));
    });

    test('the build writes into the binary dir: no configure_file of the '
        'generated CMake writes into the source dir', () async {
      await project.run(['apply', '--yes', ..._fullRun]);

      final outputs = RegExp(
        r'configure_file\(\s*"[^"]*"\s*"([^"]*)"',
      ).allMatches(project.read(_cmake)).map((match) => match.group(1));

      expect(outputs, [
        r'${CMAKE_CURRENT_BINARY_DIR}/Runner.rc',
        r'${CMAKE_CURRENT_BINARY_DIR}/main.cpp',
      ]);
    });

    test('apply records the templates as managed and the CMake file as '
        'patched in the lock', () async {
      await project.run(['apply', '--yes', ..._fullRun]);

      final lock = project.read('flavorizr.lock');

      for (final path in [_cmake, ..._templates]) {
        expect(lock, contains('$path:'));
      }
      expect(lock, contains('ownership: patched'));
      expect(lock, contains('ownership: managed'));
      expect(lock, isNot(contains('$_rc:')));
      expect(lock, isNot(contains('$_main:')));
      expect(lock, contains('apple: sha256:'));
    });

    test('an idempotent re-run produces an empty diff', () async {
      await project.run(['apply', '--yes', ..._fullRun]);
      final before = project.snapshot();

      final code = await project.run(['apply', '--yes', ..._fullRun]);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.snapshot(), before);
      expect(project.logger.output, contains('up to date'));
    });

    test('status is in sync once applied', () async {
      await project.run(['apply', '--yes', ..._fullRun]);

      final code = await project.run(['status', ..._fullRun]);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.logger.output, contains('In sync'));
    });

    test('a project that a 2.x build changed is templated, and a re-run '
        'yields no diff', () async {
      // What 2.x left in the source dir, since its configure_file wrote there.
      project.write(
        _rc,
        pristine[_rc]!
            .replaceFirst(r'resources\\app_icon.ico', r'resources\\apple.ico')
            .replaceFirst(
              'VALUE "ProductName", "example"',
              'VALUE "ProductName", "Apple App"',
            ),
      );
      project.write(
        _main,
        pristine[_main]!.replaceFirst('L"example"', 'L"Apple App"'),
      );

      final code = await project.run(['apply', '--yes', ..._fullRun]);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      templates.forEach(
        (path, template) => expect(project.read(path), template, reason: path),
      );

      final before = project.snapshot();

      expect(await project.run(['apply', ..._fullRun]), ExitCodes.ok);
      expect(project.snapshot(), before);
    });

    test('removing a flavor regenerates the region without it, and nothing '
        'else changes', () async {
      await project.run(['apply', '--yes', ..._fullRun]);
      final applied = project.snapshot();
      project.write('flavorizr.yaml', _config(['apple']));

      final code = await project.run(['apply', '--yes', ..._fullRun]);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.read(_cmake), isNot(contains('banana')));
      expect(project.read(_cmake), isNot(contains('Banana')));
      expect(
        _outsideTheRegions(project.read(_cmake)),
        _outsideTheRegions(applied[_cmake]!),
      );
      for (final path in [..._templates, _rc, _main]) {
        expect(project.read(path), applied[path], reason: path);
      }
      expect(project.read('flavorizr.lock'), isNot(contains('banana')));
    });

    test('removing the last windows flavor is refused, so no flavor is left '
        'in the region, and nothing is written', () async {
      await project.run(['apply', '--yes', ..._fullRun]);
      project.write(
        'flavorizr.yaml',
        'flavors:\n  apple:\n    app:\n      name: "Apple App"\n'
            '    android:\n      applicationId: "com.example.apple"\n',
      );
      final before = project.snapshot();

      final code = await project.run(['apply', '--yes', ..._fullRun]);

      expect(code, ExitCodes.data, reason: project.logger.output);
      expect(project.snapshot(), before);
      expect(project.logger.output, contains('windows'));
      expect(project.logger.output, contains(_cmake));
    });

    test('adding a flavor adds it to the region', () async {
      await project.run(['apply', '--yes', ..._fullRun]);
      project.write('flavorizr.yaml', _config(['apple', 'banana', 'cherry']));

      final code = await project.run(['apply', '--yes', ..._fullRun]);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.read(_cmake), contains('"Cherry App"'));
      // It has no icon: it builds with the app_icon.ico of the project.
      expect(_icon(project.read(_cmake), 'cherry'), isNull);
      expect(_icon(project.read(_cmake), 'apple'), isNull);
    });

    test('a flavor with an icon of its own is built with it', () async {
      project.write(
        'flavorizr.yaml',
        '${_config(['apple'])}'
            '  cherry:\n    app:\n      name: Cherry\n    windows:\n'
            '      icon: assets/cherry.png\n',
      );

      // The icon is made by `windows:icons`, which is not part of this run: only
      // the choice is checked here.
      final code = await project.run(['apply', '--yes', 'windows:cmake']);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(_icon(project.read(_cmake), 'cherry'), 'cherry.ico');
      expect(_icon(project.read(_cmake), 'apple'), isNull);
    });

    group('with the icons of the flavors', () {
      const icon = 'windows/runner/resources/cherry.ico';
      const withIcon =
          'flavors:\n  apple:\n    app:\n      name: "Apple App"\n'
          '    windows: {}\n'
          '  cherry:\n    app:\n      name: Cherry\n    windows:\n'
          '      icon: assets/cherry.png\n';
      const withoutIcon =
          'flavors:\n  apple:\n    app:\n      name: "Apple App"\n'
          '    windows: {}\n'
          '  cherry:\n    app:\n      name: Cherry\n    windows: {}\n';
      const withBadge =
          'badge: true\nicon: assets/cherry.png\n'
          'flavors:\n  apple:\n    app:\n      name: "Apple App"\n'
          '    badge: false\n    windows: {}\n'
          '  cherry:\n    app:\n      name: Cherry\n    windows: {}\n';
      const run = ['windows:cmake', 'windows:dummyAssets', 'windows:icons'];

      setUp(() {
        File(project.abs('assets/cherry.png'))
          ..parent.createSync(recursive: true)
          ..writeAsBytesSync(
            img.encodePng(
              img.Image(width: 1024, height: 1024)
                ..clear(img.ColorRgb8(200, 30, 30)),
            ),
          );
      });

      test('the .ico is made, and the flavor is built with it', () async {
        project.write('flavorizr.yaml', withIcon);

        final code = await project.run(['apply', '--yes', ...run]);

        expect(code, ExitCodes.ok, reason: project.logger.output);
        expect(project.exists(icon), isTrue);
        expect(_icon(project.read(_cmake), 'cherry'), 'cherry.ico');
        expect(_icon(project.read(_cmake), 'apple'), isNull);
      });

      test('a re-run produces an empty diff', () async {
        project.write('flavorizr.yaml', withIcon);
        await project.run(['apply', '--yes', ...run]);
        final cmake = project.read(_cmake);
        final lock = project.read('flavorizr.lock');
        final bytes = File(project.abs(icon)).readAsBytesSync();

        final code = await project.run(['apply', '--yes', ...run]);

        expect(code, ExitCodes.ok, reason: project.logger.output);
        expect(project.read(_cmake), cmake);
        expect(project.read('flavorizr.lock'), lock);
        expect(File(project.abs(icon)).readAsBytesSync(), bytes);
        expect(project.logger.output, contains('up to date'));
      });

      test('the .ico of a badge is made, and the flavor is built with it, '
          'without an icon of its own', () async {
        project.write('flavorizr.yaml', withBadge);

        final code = await project.run(['apply', '--yes', ...run]);

        expect(code, ExitCodes.ok, reason: project.logger.output);
        expect(project.exists(icon), isTrue);
        expect(_icon(project.read(_cmake), 'cherry'), 'cherry.ico');
        expect(_icon(project.read(_cmake), 'apple'), isNull);
        expect(project.exists('windows/runner/resources/apple.ico'), isFalse);
      });

      test('a flavor that loses its icon is built with the icon of the project '
          'in the run that removes its .ico', () async {
        project.write('flavorizr.yaml', withIcon);
        await project.run(['apply', '--yes', ...run]);

        project.write('flavorizr.yaml', withoutIcon);
        final code = await project.run(['apply', '--yes', ...run]);

        expect(code, ExitCodes.ok, reason: project.logger.output);
        expect(project.exists(icon), isFalse);
        expect(_icon(project.read(_cmake), 'cherry'), isNull);
      });

      test(
        'the same goes when the processors run apart, in either order',
        () async {
          project.write('flavorizr.yaml', withIcon);
          await project.run(['apply', '--yes', ...run]);

          project.write('flavorizr.yaml', withoutIcon);
          await project.run(['apply', '--yes', 'windows:cmake']);

          expect(_icon(project.read(_cmake), 'cherry'), isNull);
          expect(project.exists(icon), isTrue);

          await project.run(['apply', '--yes', 'windows:icons']);

          expect(project.exists(icon), isFalse);
          expect(_icon(project.read(_cmake), 'cherry'), isNull);
        },
      );

      test('a flavor that loses its badge is built with the icon of the '
          'project too', () async {
        project.write('flavorizr.yaml', withBadge);
        await project.run(['apply', '--yes', ...run]);

        project.write(
          'flavorizr.yaml',
          withBadge.replaceFirst('badge: true', ''),
        );
        final code = await project.run(['apply', '--yes', ...run]);

        expect(code, ExitCodes.ok, reason: project.logger.output);
        expect(project.exists(icon), isFalse);
        expect(_icon(project.read(_cmake), 'cherry'), isNull);
      });

      test('a flavor that is dropped loses its .ico and its branch', () async {
        project.write('flavorizr.yaml', withIcon);
        await project.run(['apply', '--yes', ...run]);

        project.write('flavorizr.yaml', _config(['apple', 'banana']));
        final code = await project.run(['apply', '--yes', ...run]);

        expect(code, ExitCodes.ok, reason: project.logger.output);
        expect(project.exists(icon), isFalse);
        expect(project.read(_cmake), isNot(contains('cherry')));
      });

      test('the .ico of the user stays the icon of the flavor, whatever the '
          'flavor does, while the lock does not know it', () async {
        project.write('windows/runner/resources/apple.ico', 'MINE');
        project.write('flavorizr.yaml', withoutIcon);

        await project.run(['apply', '--yes', ...run]);

        expect(_icon(project.read(_cmake), 'apple'), 'apple.ico');
        expect(project.read('windows/runner/resources/apple.ico'), 'MINE');

        await project.run(['apply', '--yes', ...run]);

        expect(_icon(project.read(_cmake), 'apple'), 'apple.ico');
        expect(project.read('windows/runner/resources/apple.ico'), 'MINE');
      });
    });

    test('a flavor whose icon is already in the project is built with it, '
        'and the file is left alone', () async {
      project.write('windows/runner/resources/apple.ico', 'MINE');

      await project.run(['apply', '--yes', ..._fullRun]);

      expect(_icon(project.read(_cmake), 'apple'), 'apple.ico');
      expect(_icon(project.read(_cmake), 'banana'), isNull);
      expect(project.read('windows/runner/resources/apple.ico'), 'MINE');
    });

    test('what the user writes outside the region is no drift and survives '
        'the next run', () async {
      await project.run(['apply', '--yes', ..._fullRun]);
      project.write(_cmake, '# mine\n${project.read(_cmake)}');
      final edited = project.snapshot();

      expect(await project.run(['status', ..._fullRun]), ExitCodes.ok);
      expect(await project.run(['apply', '--yes', ..._fullRun]), ExitCodes.ok);
      expect(project.snapshot(), edited);
    });

    test(
      'a change to Runner.rc is what the template is regenerated from',
      () async {
        await project.run(['apply', '--yes', ..._fullRun]);
        project.write(_rc, '${project.read(_rc)}// mine\n');

        final code = await project.run(['apply', '--yes', ..._fullRun]);

        expect(code, ExitCodes.ok, reason: project.logger.output);
        expect(project.read(_rcIn), '${templates[_rcIn]}// mine\n');
      },
    );

    test(
      'a hand edit of the region is a conflict, and nothing is written',
      () async {
        await project.run(['apply', '--yes', ..._fullRun]);
        project.write(
          _cmake,
          project.read(_cmake).replaceFirst('Apple App', 'Mine'),
        );
        project.write('flavorizr.yaml', _config(['apple', 'cherry']));
        final before = project.snapshot();

        final code = await project.run(['apply', '--yes', ..._fullRun]);

        expect(code, ExitCodes.attention);
        expect(project.snapshot(), before);
        expect(project.logger.output, contains(_cmake));
      },
    );

    test(
      'a hand edit of a template is a conflict, and nothing is written',
      () async {
        await project.run(['apply', '--yes', ..._fullRun]);
        project.write(_mainIn, '${project.read(_mainIn)}// mine\n');
        project.write('flavorizr.yaml', _config(['apple', 'cherry']));
        final before = project.snapshot();

        final code = await project.run(['apply', '--yes', ..._fullRun]);

        expect(code, ExitCodes.attention);
        expect(project.snapshot(), before);
        expect(project.logger.output, contains(_mainIn));
      },
    );

    test(
      'a project flavorized by a 2.x run is adopted: the templates are the '
      'ones 2.x wrote, and only the region of the CMake file changes',
      () async {
        project.write(
          _cmake,
          _resource(
            'runner_cmake_lists_processor_test/CMakeLists_expected.txt',
          ),
        );
        templates.forEach(project.write);
        final before = project.snapshot();

        final code = await project.run(['apply', '--yes', ..._fullRun]);

        expect(code, ExitCodes.ok, reason: project.logger.output);
        expect(project.exists('flavorizr.lock'), isTrue);

        final after = project.snapshot();

        for (final path in [..._templates, _rc, _main]) {
          expect(after[path], before[path], reason: path);
        }
        expect(after[_cmake], isNot(before[_cmake]));
        expect(
          after[_cmake],
          contains(r'"${CMAKE_CURRENT_BINARY_DIR}/Runner.rc"'),
        );
        expect(
          after[_cmake],
          isNot(
            contains(
              r'"${CMAKE_CURRENT_SOURCE_DIR}/Runner.rc"'
              '\n  @ONLY',
            ),
          ),
        );
      },
    );

    test('a missing Runner.rc fails the run and writes nothing', () async {
      File(project.abs(_rc)).deleteSync();
      final before = project.snapshot();

      final code = await project.run(['apply', '--yes', ..._fullRun]);

      expect(code, ExitCodes.software);
      expect(project.snapshot(), before);
    });

    test('a CMake file it cannot edit fails the run with what to change, '
        'and writes nothing', () async {
      project.write(
        _cmake,
        pristine[_cmake]!.replaceFirst(
          'add_executable(\${BINARY_NAME} WIN32',
          'add_executable(\${BINARY_NAME} WIN32 "main.cpp"',
        ),
      );
      final before = project.snapshot();

      final code = await project.run(['apply', '--yes', ..._fullRun]);

      expect(code, ExitCodes.software);
      expect(project.snapshot(), before);
      expect(project.logger.output, contains('Then run flavorizr again.'));
    });
  });
}
