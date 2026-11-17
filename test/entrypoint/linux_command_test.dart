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

const _cmake = 'linux/CMakeLists.txt';
const _runner = 'linux/runner/CMakeLists.txt';
const _myApplication = 'linux/runner/my_application.cc';
const _paths = [_cmake, _runner, _myApplication];

String _resource(String path) =>
    File('test_resources/linux/$path').readAsStringSync();

String _config(Iterable<String> flavors, {bool android = false}) =>
    'flavors:\n${[for (final flavor in flavors) '''
  $flavor:
    app:
      name: "${flavor[0].toUpperCase()}${flavor.substring(1)} App"
${android ? '''
    android:
      applicationId: "com.example.$flavor"
''' : ''}    linux:
      applicationId: "com.example.$flavor"
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
  late Map<String, String> pristine;

  setUp(() {
    project = CliFixture(android: false);
    pristine = {
      _cmake: _resource('cmake_lists_processor_test/CMakeLists.txt'),
      _runner: _resource('runner_cmake_lists_processor_test/CMakeLists.txt'),
      _myApplication: _resource(
        'my_application_processor_test/my_application.cc',
      ),
    };
    project.write('flavorizr.yaml', _config(['apple', 'banana']));
    pristine.forEach(project.write);
  });
  tearDown(() => project.dispose());

  group('the linux processors on the engine', () {
    test('plan lists them on the engine and none for the legacy pipeline, '
        'and writes nothing', () async {
      final before = project.snapshot();

      final code = await project.run(['plan', 'linux']);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.logger.output, contains('1. linux:cmake'));
      expect(project.logger.output, contains('linux:runnerCmake'));
      expect(project.logger.output, contains('linux:myApplication'));
      expect(project.logger.output, isNot(contains('not on the engine')));
      expect(project.snapshot(), before);
    });

    test('apply on a pristine runner changes only marked regions', () async {
      final code = await project.run(['apply', '--yes', 'linux']);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.legacy.ran, isEmpty);

      for (final path in _paths) {
        final patched = project.read(path);

        expect(patched, isNot(pristine[path]), reason: path);
        expect(
          _outsideTheRegions(patched),
          _outsideTheRegions(pristine[path]!),
          reason: path,
        );
      }
      expect(project.read(_cmake), contains('com.example.banana'));
      expect(project.read(_runner), contains('FLUTTER_APP_FLAVOR'));
      expect(project.read(_myApplication), contains('Banana App'));
    });

    test('apply records the three files as patched in the lock', () async {
      await project.run(['apply', '--yes', 'linux']);

      final lock = project.read('flavorizr.lock');

      for (final path in _paths) {
        expect(lock, contains('$path:'));
      }
      expect(lock, contains('ownership: patched'));
      expect(lock, contains('apple: sha256:'));
    });

    test('an idempotent re-run produces an empty diff', () async {
      await project.run(['apply', '--yes', 'linux']);
      final before = project.snapshot();
      project.questions.clear();

      final code = await project.run(['apply', 'linux']);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.questions, isEmpty);
      expect(project.snapshot(), before);
      expect(project.logger.output, contains('up to date'));
    });

    test('status is in sync once applied', () async {
      await project.run(['apply', '--yes', 'linux']);

      final code = await project.run(['status', 'linux']);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.logger.output, contains('In sync'));
    });

    test('removing a flavor regenerates the regions without it, and nothing '
        'else changes', () async {
      await project.run(['apply', '--yes', 'linux']);
      final applied = {for (final path in _paths) path: project.read(path)};
      project.write('flavorizr.yaml', _config(['apple']));

      final code = await project.run(['apply', '--yes', 'linux']);

      expect(code, ExitCodes.ok, reason: project.logger.output);

      for (final path in _paths) {
        expect(project.read(path), isNot(contains('banana')), reason: path);
        expect(project.read(path), isNot(contains('Banana')), reason: path);
        expect(
          _outsideTheRegions(project.read(path)),
          _outsideTheRegions(applied[path]!),
          reason: path,
        );
      }
      expect(project.read('flavorizr.lock'), isNot(contains('banana')));
      expect(project.read(_cmake), contains('com.example.apple'));
    });

    test('adding a flavor adds it to the regions', () async {
      await project.run(['apply', '--yes', 'linux']);
      project.write('flavorizr.yaml', _config(['apple', 'banana', 'cherry']));

      final code = await project.run(['apply', '--yes', 'linux']);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.read(_cmake), contains('com.example.cherry'));
      expect(project.read(_myApplication), contains('Cherry App'));
    });

    test('what the user writes outside the regions is no drift and survives '
        'the next run', () async {
      await project.run(['apply', '--yes', 'linux']);
      for (final path in _paths) {
        project.write(path, '// mine\n${project.read(path)}');
      }
      final edited = project.snapshot();

      expect(await project.run(['status', 'linux']), ExitCodes.ok);
      expect(await project.run(['apply', '--yes', 'linux']), ExitCodes.ok);
      expect(project.snapshot(), edited);
    });

    test(
      'a hand edit of a region is a conflict, and nothing is written',
      () async {
        await project.run(['apply', '--yes', 'linux']);
        project.write(
          _cmake,
          project.read(_cmake).replaceFirst('com.example.apple', 'com.mine'),
        );
        project.write('flavorizr.yaml', _config(['apple', 'cherry']));
        final before = project.snapshot();

        final code = await project.run(['apply', '--yes', 'linux']);

        expect(code, ExitCodes.attention);
        expect(project.snapshot(), before);
        expect(project.logger.output, contains(_cmake));
      },
    );

    test('a project flavorized by a 2.x run is adopted without a diff in the '
        'regions', () async {
      // What 2.x wrote: the same regions, markers included.
      project.write(
        _cmake,
        _resource('cmake_lists_processor_test/CMakeLists_expected.txt'),
      );
      project.write(
        _runner,
        _resource('runner_cmake_lists_processor_test/CMakeLists_expected.txt'),
      );
      project.write(
        _myApplication,
        _resource('my_application_processor_test/my_application_expected.cc'),
      );
      final before = project.snapshot();

      final code = await project.run(['apply', '--yes', 'linux']);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(
        {for (final path in _paths) path: project.read(path)},
        {for (final path in _paths) path: before[path]},
      );
      expect(project.exists('flavorizr.lock'), isTrue);
    });

    test('a missing runner fails the run and writes nothing', () async {
      File(project.abs(_runner)).deleteSync();
      final before = project.snapshot();

      final code = await project.run(['apply', '--yes', 'linux']);

      expect(code, ExitCodes.software);
      expect(project.snapshot(), before);
    });

    test('the lock records the flavors only once every processor that applies '
        'ran: Android and Linux together', () async {
      project.write('flavorizr.yaml', _config(['apple'], android: true));
      project.write(
        'android/app/src/main/AndroidManifest.xml',
        '<manifest xmlns:android="http://schemas.android.com/apk/res/android">'
            '<application android:label="x"/></manifest>',
      );
      project.write(
        'android/app/build.gradle',
        'android {\n    namespace "com.example.app"\n}\n',
      );
      const android = [
        'android:androidManifest',
        'android:buildGradle',
        'android:icons',
      ];

      expect(
        await project.run(['apply', '--yes', 'linux']),
        ExitCodes.ok,
        reason: project.logger.output,
      );
      expect(project.read('flavorizr.lock'), isNot(contains('apple: sha256')));

      expect(
        await project.run(['apply', '--yes', ...android, 'linux']),
        ExitCodes.ok,
        reason: project.logger.output,
      );
      expect(project.read('flavorizr.lock'), contains('apple: sha256:'));
    });
  });
}
