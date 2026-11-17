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

const _ios = 'ios/Podfile';
const _macos = 'macos/Podfile';
const _paths = [_ios, _macos];

/// What a full run of a project with only iOS and macOS flavors covers.
const _fullRun = [
  'flutter:flavors',
  'ios:podfile',
  'macos:podfile',
  'ios:xcconfig',
  'macos:xcconfig',
  'macos:configs',
];

final String _pristine = File(
  'test_resources/darwin/podfile_test/PodfileOriginal',
).readAsStringSync();

String _config(Iterable<String> flavors) =>
    'flavors:\n${[for (final flavor in flavors) '''
  $flavor:
    app:
      name: "$flavor app"
    ios:
      bundleId: "com.example.$flavor"
    macos:
      bundleId: "com.example.$flavor"
'''].join()}';

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

  setUp(() {
    project = CliFixture(android: false);
    project.write('flavorizr.yaml', _config(['apple', 'banana']));
    for (final path in _paths) {
      project.write(path, _pristine);
    }
    for (final platform in ['ios', 'macos']) {
      final path = '$platform/Runner.xcodeproj/project.pbxproj';
      project.write(path, File('example/$path').readAsStringSync());
    }
  });
  tearDown(() => project.dispose());

  group('the Podfile processors on the engine', () {
    test('plan lists them on the engine and none for the legacy pipeline, '
        'and writes nothing', () async {
      final before = project.snapshot();

      final code = await project.run(['plan', 'ios:podfile', 'macos:podfile']);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.logger.output, contains('1. ios:podfile'));
      expect(project.logger.output, contains('macos:podfile'));
      expect(project.logger.output, isNot(contains('not on the engine')));
      expect(project.snapshot(), before);
    });

    test('apply on a Podfile as flutter create writes it adds only the '
        'region, and keeps the default mappings', () async {
      final code = await project.run(['apply', '--yes', ..._fullRun]);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.legacy.ran, isEmpty);

      for (final path in _paths) {
        final patched = project.read(path);

        expect(patched, isNot(_pristine), reason: path);
        expect(
          _outsideTheRegions(patched),
          _outsideTheRegions(_pristine),
          reason: path,
        );
        expect(patched, contains("'Debug-apple' => :debug,"), reason: path);
        expect(patched, contains("'Release-banana' => :release,"));
        expect(patched, contains("  'Debug' => :debug,"), reason: path);
        expect(patched, contains("  'Release' => :release,"), reason: path);
      }
    });

    test('apply records the Podfiles as patched in the lock', () async {
      await project.run(['apply', '--yes', ..._fullRun]);

      final lock = project.read('flavorizr.lock');

      for (final path in _paths) {
        expect(lock, contains('$path:'));
      }
      expect(lock, contains('ownership: patched'));
      expect(lock, contains('apple: sha256:'));
    });

    test('an idempotent re-run produces an empty diff', () async {
      await project.run(['apply', '--yes', ..._fullRun]);
      final before = project.snapshot();
      project.questions.clear();

      final code = await project.run(['apply', ..._fullRun]);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.questions, isEmpty);
      expect(project.snapshot(), before);
      expect(project.logger.output, contains('up to date'));
    });

    test('status is in sync once applied', () async {
      await project.run(['apply', '--yes', ..._fullRun]);

      final code = await project.run(['status', ..._fullRun]);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.logger.output, contains('In sync'));
    });

    test('removing a flavor takes its mappings out of the region, and '
        'nothing else changes', () async {
      await project.run(['apply', '--yes', ..._fullRun]);
      final applied = {for (final path in _paths) path: project.read(path)};
      project.write('flavorizr.yaml', _config(['apple']));

      final code = await project.run(['apply', '--yes', ..._fullRun]);

      expect(code, ExitCodes.ok, reason: project.logger.output);

      for (final path in _paths) {
        expect(project.read(path), isNot(contains('banana')), reason: path);
        expect(project.read(path), contains("'Debug-apple' => :debug,"));
        expect(
          _outsideTheRegions(project.read(path)),
          _outsideTheRegions(applied[path]!),
          reason: path,
        );
      }
      expect(project.read('flavorizr.lock'), isNot(contains('banana')));
    });

    test('removing the last flavor of a platform is refused, so no flavor is '
        'left in its Podfile, and nothing is written', () async {
      await project.run(['apply', '--yes', ..._fullRun]);
      project.write(
        'flavorizr.yaml',
        'flavors:\n  apple:\n    app:\n      name: "apple"\n'
            '    ios:\n      bundleId: "com.example.apple"\n',
      );
      final before = project.snapshot();

      final code = await project.run(['apply', '--yes', ..._fullRun]);

      expect(code, ExitCodes.data, reason: project.logger.output);
      expect(project.snapshot(), before);
      expect(project.logger.output, contains('macos'));
    });

    test('adding a flavor adds its mappings to the region', () async {
      await project.run(['apply', '--yes', ..._fullRun]);
      project.write('flavorizr.yaml', _config(['apple', 'banana', 'cherry']));

      final code = await project.run(['apply', '--yes', ..._fullRun]);

      expect(code, ExitCodes.ok, reason: project.logger.output);

      for (final path in _paths) {
        expect(project.read(path), contains("'Profile-cherry' => :release,"));
      }
    });

    test('what the user writes outside the region is no drift and survives '
        'the next run', () async {
      await project.run(['apply', '--yes', ..._fullRun]);
      for (final path in _paths) {
        project.write(
          path,
          '# mine\n${project.read(path).replaceFirst("'Debug' => :debug,", "'Debug' => :debug, # also mine")}',
        );
      }
      final edited = project.snapshot();

      expect(await project.run(['status', ..._fullRun]), ExitCodes.ok);
      expect(await project.run(['apply', '--yes', ..._fullRun]), ExitCodes.ok);
      expect(project.snapshot(), edited);
    });

    test(
      'a hand edit of the region is a conflict, and nothing is written',
      () async {
        await project.run(['apply', '--yes', ..._fullRun]);
        project.write(
          _ios,
          project.read(_ios).replaceFirst("'Debug-apple'", "'Debug-mine'"),
        );
        project.write('flavorizr.yaml', _config(['apple', 'cherry']));
        final before = project.snapshot();

        final code = await project.run(['apply', '--yes', ..._fullRun]);

        expect(code, ExitCodes.attention);
        expect(project.snapshot(), before);
        expect(project.logger.output, contains(_ios));
      },
    );

    test('a Podfile flavorized by 2.x is adopted: the markers and the default '
        'mappings 2.x dropped are the only difference', () async {
      // What 2.x wrote: the mappings right after the opening line, with the
      // default ones gone.
      final flavorized = _pristine.replaceFirst(
        RegExp(
          r"  'Debug' => :debug,\n  'Profile' => :release,\n  'Release' => :release,\n",
        ),
        [
          for (final flavor in ['apple', 'banana']) ...[
            "  'Debug-$flavor' => :debug,\n",
            "  'Profile-$flavor' => :release,\n",
            "  'Release-$flavor' => :release,\n",
          ],
        ].join(),
      );
      for (final path in _paths) {
        project.write(path, flavorized);
      }

      final code = await project.run(['apply', '--yes', ..._fullRun]);

      expect(code, ExitCodes.ok, reason: project.logger.output);

      for (final path in _paths) {
        final patched = project.read(path);
        final lines = patched.split('\n');
        final begin = lines.indexWhere((line) => line.contains('BEGIN '));
        final end = lines.indexWhere((line) => line.contains('END '));

        expect(lines.sublist(begin + 1, end), [
          "  'Debug' => :debug,",
          "  'Profile' => :release,",
          "  'Release' => :release,",
          for (final flavor in ['apple', 'banana']) ...[
            "  'Debug-$flavor' => :debug,",
            "  'Profile-$flavor' => :release,",
            "  'Release-$flavor' => :release,",
          ],
        ], reason: path);
        expect(
          [...lines.sublist(0, begin), ...lines.sublist(end + 1)],
          flavorized
              .replaceFirst(
                RegExp(
                  r"(  'Debug-\w+' => :debug,\n  'Profile-\w+' => :release,\n  'Release-\w+' => :release,\n)+",
                ),
                '',
              )
              .split('\n'),
          reason: '$path: nothing but the mapping changed',
        );
      }

      final before = project.snapshot();

      expect(await project.run(['apply', '--yes', ..._fullRun]), ExitCodes.ok);
      expect(project.snapshot(), before, reason: 'the second run is empty');
    });

    test(
      'a project with no Podfile yet is not an error, and gets none',
      () async {
        File(project.abs(_ios)).deleteSync();
        File(project.abs(_macos)).deleteSync();

        final code = await project.run(['apply', '--yes', ..._fullRun]);

        expect(code, ExitCodes.ok, reason: project.logger.output);
        expect(project.exists(_ios), isFalse);
        expect(project.exists(_macos), isFalse);
      },
    );

    test('a Podfile that is gone after it was patched is not an error, and '
        'is not made again', () async {
      await project.run(['apply', '--yes', ..._fullRun]);
      File(project.abs(_ios)).deleteSync();

      final code = await project.run(['apply', '--yes', ..._fullRun]);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.exists(_ios), isFalse);
      expect(project.read('flavorizr.lock'), isNot(contains('$_ios:')));
      expect(project.read('flavorizr.lock'), contains('$_macos:'));
    });

    test('a Podfile whose mapping is not like flutter create writes it fails '
        'the run, says what to change and writes nothing', () async {
      project.write(
        _macos,
        _pristine.replaceFirst(
          "'Release' => :release,\n",
          "'Release' => :release }\n",
        ),
      );
      final before = project.snapshot();

      final code = await project.run(['apply', '--yes', ..._fullRun]);

      expect(code, ExitCodes.software);
      expect(project.snapshot(), before);
      expect(project.logger.output, contains('Cannot flavor macos/Podfile'));
      expect(project.logger.output, contains('run flavorizr again'));
    });
  });
}
