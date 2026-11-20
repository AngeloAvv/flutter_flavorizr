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
final golden2x = Directory('tool/parity/golden/2.6.0/tree');

/// The Firebase configurations the fixture points at, and the configuration of
/// the flavors in the words of 3.x.
final parityFixtures = Directory('tool/parity/fixtures');

const densities = ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi'];

/// What a dummy icon holds in these projects, which have no binary files (the
/// golden keeps their hashes only).
String dummyBytes(String density) => 'dummy launcher icon $density';

final dummies = DummyAssets({
  for (final density in densities)
    'android/res/mipmap-$density/ic_launcher.png': DummyAssets.hashOf(
      utf8.encode(dummyBytes(density)),
    ),
});

String icon(String flavor, String density) =>
    'android/app/src/$flavor/res/mipmap-$density/ic_launcher.png';

/// A project flavorized by 2.6.0: the files the harness recorded, with the 3.x
/// configuration. `apple` still has the dummy icons of 2.x, `banana` has its
/// own.
CliFixture project2x() {
  final project = CliFixture(android: false)..dummyAssets = dummies;

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

  copy(golden2x, where: (path) => path != 'flavorizr.yaml');
  copy(Directory(p.join(parityFixtures.path, 'files')));

  project.write(
    'flavorizr.yaml',
    File(p.join(parityFixtures.path, 'flavorizr.3.yaml')).readAsStringSync(),
  );

  for (final density in densities) {
    project.write(icon('apple', density), dummyBytes(density));
    project.write(icon('banana', density), 'the logo of banana');
  }

  return project;
}

Future<FlavorizrLock?> lockOf(CliFixture project) =>
    LockStore(project.root, runningVersion: '3.0.0').read();

/// What `plan` would do, by path, as the document of `--json` says.
Future<Map<String, String>> planned(CliFixture project) async {
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
