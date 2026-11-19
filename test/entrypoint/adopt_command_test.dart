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

import 'package:flutter_flavorizr/src/engine/adopt/dummy_assets.dart';
import 'package:flutter_flavorizr/src/engine/lock/flavorizr_lock.dart';
import 'package:flutter_flavorizr/src/engine/lock/lock_store.dart';
import 'package:flutter_flavorizr/src/entrypoint/exit_codes.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'cli_fixture.dart';

/// What flavorizr 2.6.0 made of a new project, as the parity harness recorded
/// it: the project has `apple` and `banana`, built for every platform.
final _golden = Directory('tool/parity/golden/2.6.0/tree');

/// The Firebase configurations the fixture points at, and the configuration of
/// the flavors in the words of 3.x.
final _fixtures = Directory('tool/parity/fixtures');

const _densities = ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi'];

/// What a dummy icon holds in these projects, which have no binary files (the
/// golden keeps their hashes only).
String _dummyBytes(String density) => 'dummy launcher icon $density';

final _dummies = DummyAssets({
  for (final density in _densities)
    'android/res/mipmap-$density/ic_launcher.png': DummyAssets.hashOf(
      utf8.encode(_dummyBytes(density)),
    ),
});

String _icon(String flavor, String density) =>
    'android/app/src/$flavor/res/mipmap-$density/ic_launcher.png';

/// A project flavorized by 2.6.0: the files the harness recorded, with the 3.x
/// configuration. `apple` still has the dummy icons of 2.x, `banana` has its
/// own.
CliFixture _project2x() {
  final project = CliFixture(android: false)..dummyAssets = _dummies;

  void copy(Directory from, {bool Function(String path)? where}) {
    for (final file in from.listSync(recursive: true).whereType<File>()) {
      final path = p.relative(file.path, from: from.path);

      if (file.path.endsWith('.sha256') || (where?.call(path) == false)) {
        continue;
      }

      File(project.abs(path))
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(file.readAsBytesSync());
    }
  }

  copy(_golden, where: (path) => path != 'flavorizr.yaml');
  copy(Directory(p.join(_fixtures.path, 'files')));

  project.write(
    'flavorizr.yaml',
    File(p.join(_fixtures.path, 'flavorizr.3.yaml')).readAsStringSync(),
  );

  for (final density in _densities) {
    project.write(_icon('apple', density), _dummyBytes(density));
    project.write(_icon('banana', density), 'the logo of banana');
  }

  return project;
}

Future<FlavorizrLock?> _lockOf(CliFixture project) =>
    LockStore(project.root, runningVersion: '3.0.0').read();

/// What `plan` would do, by path, as the document of `--json` says.
Future<Map<String, String>> _planned(CliFixture project) async {
  project.stdout.clear();

  final code = await project.run(['plan', '--json']);

  expect(code, ExitCodes.ok, reason: project.logger.output);

  final changes =
      (jsonDecode(project.stdout.toString()) as Map<String, Object?>)['changes']
          as List<Object?>;

  return {
    for (final change in changes.cast<Map<String, Object?>>())
      change['path']! as String: '${change['change']}/${change['disposition']}',
  };
}

void main() {
  late CliFixture project;

  setUp(() => project = _project2x());
  tearDown(() => project.dispose());

  group('adopt', () {
    test('writes flavorizr.lock and nothing else', () async {
      final before = project.snapshot();

      final code = await project.run(['adopt']);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.exists('flavorizr.lock'), isTrue);
      expect({...project.snapshot()}..remove('flavorizr.lock'), before);
    });

    test('is followed by a plan with no conflict, and no deletion of what the '
        'project is made of', () async {
      await project.run(['adopt']);

      final changes = await _planned(project);

      expect(
        changes.values.where((change) => change.endsWith('/conflict')),
        isEmpty,
        reason: '$changes',
      );
      expect(
        [
          for (final MapEntry(key: path, value: change) in changes.entries)
            if (change.startsWith('deleted/')) path,
        ],
        unorderedEquals([
          // The dummy icons of 2.x, which 3.0 no longer makes.
          for (final density in _densities) _icon('apple', density),
        ]),
      );
    });

    test('is what makes a plan of the project reviewable', () async {
      // Without a baseline, what 2.x wrote cannot be told from what the user
      // wrote: the files are conflicts.
      final code = await project.run(['plan']);

      expect(code, ExitCodes.attention);
    });

    test('leaves the icons the user replaced alone', () async {
      await project.run(['adopt']);

      final lock = await _lockOf(project);

      expect(
        lock!.processors['android:icons']!.files.keys,
        unorderedEquals([
          for (final density in _densities) _icon('apple', density),
        ]),
      );
      expect(await _planned(project), isNot(contains(_icon('banana', 'hdpi'))));
      expect(project.logger.output, contains(_icon('banana', 'hdpi')));
    });

    test('records the flavors of the configuration', () async {
      await project.run(['adopt']);

      expect((await _lockOf(project))!.flavorNames, {'apple', 'banana'});
    });

    test('refuses a project that has a lock already', () async {
      await project.run(['adopt']);
      final lock = project.read('flavorizr.lock');

      project.logger.lines.clear();
      final code = await project.run(['adopt']);

      expect(code, ExitCodes.data);
      expect(project.logger.output, contains('flavorizr.lock'));
      expect(project.read('flavorizr.lock'), lock);
    });

    test('says what it did', () async {
      await project.run(['adopt']);

      expect(project.logger.output, contains('Adopted'));
    });

    test('fails without a configuration', () async {
      File(project.abs('flavorizr.yaml')).deleteSync();

      final code = await project.run(['adopt']);

      expect(code, ExitCodes.data);
      expect(project.exists('flavorizr.lock'), isFalse);
    });

    group('--flavors', () {
      test('declares the flavors the project had, so that the next plan '
          'removes them', () async {
        project.write(_icon('cherry', 'hdpi'), _dummyBytes('hdpi'));
        project.write('ios/Flutter/cherryDebug.xcconfig', '// 2.x');

        final code = await project.run(['adopt', '--flavors', 'cherry']);

        expect(code, ExitCodes.ok, reason: project.logger.output);

        final lock = await _lockOf(project);

        expect(lock!.flavorNames, {'apple', 'banana', 'cherry'});
        expect(
          lock.processors['android:icons']!.files.keys,
          contains(_icon('cherry', 'hdpi')),
        );

        final changes = await _planned(project);

        expect(changes[_icon('cherry', 'hdpi')], startsWith('deleted/'));
        expect(
          changes['ios/Flutter/cherryDebug.xcconfig'],
          startsWith('deleted/'),
        );
      });

      test('takes a list', () async {
        final code = await project.run(['adopt', '--flavors', 'cherry,lemon']);

        expect(code, ExitCodes.ok, reason: project.logger.output);
        expect((await _lockOf(project))!.flavorNames, {
          'apple',
          'banana',
          'cherry',
          'lemon',
        });
      });

      test('does not take a name that is not a folder', () async {
        final code = await project.run(['adopt', '--flavors', '../x']);

        expect(code, ExitCodes.usage);
        expect(project.exists('flavorizr.lock'), isFalse);
      });
    });
  });
}
