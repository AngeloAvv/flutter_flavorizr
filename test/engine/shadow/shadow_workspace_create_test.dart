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

import 'package:flutter_flavorizr/src/engine/shadow/shadow_workspace.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'shadow_fixture.dart';

void main() {
  late ShadowFixture fx;

  setUp(() => fx = ShadowFixture());
  tearDown(() => fx.dispose());

  group('ShadowWorkspace.create', () {
    test('copies a whitelisted file into the shadow root', () async {
      fx.project.write('lib/flavors.dart', 'old');

      final shadow = await fx.create(['lib/flavors.dart']);

      expect(shadow.read('lib/flavors.dart'), 'old');
      expect(shadow.root.path, isNot(fx.project.root.path));
    });

    test('does not copy anything that is not whitelisted', () async {
      fx.project.write('lib/flavors.dart', 'old');
      fx.project.write('lib/other.dart', 'other');
      fx.project.write('pubspec.yaml', 'name: x');

      final shadow = await fx.create(['lib/flavors.dart']);

      expect(shadow.exists('lib/other.dart'), isFalse);
      expect(shadow.exists('pubspec.yaml'), isFalse);
    });

    test('copies a whitelisted directory recursively', () async {
      fx.project.write('android/app/src/main/a.xml', 'a');
      fx.project.write('android/app/src/main/res/b.xml', 'b');

      final shadow = await fx.create(['android/app/src']);

      expect(shadow.read('android/app/src/main/a.xml'), 'a');
      expect(shadow.read('android/app/src/main/res/b.xml'), 'b');
    });

    test('tolerates a whitelisted path that does not exist yet', () async {
      final shadow = await fx.create(['lib/flavors.dart']);

      expect(shadow.exists('lib/flavors.dart'), isFalse);
      expect(shadow.root.existsSync(), isTrue);
    });

    test(
      'never copies ignored folders found inside a whitelisted one',
      () async {
        for (final ignored in [
          'build',
          '.dart_tool',
          '.git',
          '.gradle',
          '.cxx',
          'Pods',
          '.symlinks',
          'ephemeral',
        ]) {
          fx.project.write('ios/$ignored/file.txt', 'x');
        }
        fx.project.write('ios/Runner/Info.plist', 'plist');

        final shadow = await fx.create(['ios']);

        expect(shadow.read('ios/Runner/Info.plist'), 'plist');
        expect(
          Directory(
            p.join(shadow.root.path, 'ios'),
          ).listSync().map((e) => p.basename(e.path)),
          ['Runner'],
        );
      },
    );

    test('rejects a whitelisted path that leaves the project', () async {
      expect(
        () => fx.create(['../outside.txt']),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => fx.create([p.join(fx.project.root.path, 'lib')]),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects a whitelisted path that is an ignored folder', () async {
      expect(() => fx.create(['build']), throwsA(isA<ArgumentError>()));
      expect(
        () => fx.create(['android/app/.cxx']),
        throwsA(isA<ArgumentError>()),
      );
    });

    group('symbolic links', () {
      late Directory outside;

      setUp(() {
        outside = Directory(p.join(fx.scratch.path, 'outside'))..createSync();
        File(p.join(outside.path, 'secret.txt')).writeAsStringSync('secret');
      });

      test('are never followed out of the project', () async {
        fx.project.write('ios/Runner/Info.plist', 'plist');
        Link(fx.project.abs('ios/linked')).createSync(outside.path);

        final shadow = await fx.create(['ios']);

        expect(shadow.exists('ios/linked'), isFalse);
        expect(shadow.exists('ios/linked/secret.txt'), isFalse);
        expect(shadow.read('ios/Runner/Info.plist'), 'plist');
        expect(shadow.skippedLinks, ['ios/linked']);
      });

      test('are skipped when whitelisted themselves', () async {
        Link(
          fx.project.abs('link.txt'),
        ).createSync(p.join(outside.path, 'secret.txt'));

        final shadow = await fx.create(['link.txt']);

        expect(shadow.exists('link.txt'), isFalse);
        expect(shadow.skippedLinks, ['link.txt']);
      });

      test('are skipped when a parent of a whitelisted path is one', () async {
        Link(fx.project.abs('ios')).createSync(outside.path);

        final shadow = await fx.create(['ios/secret.txt']);

        expect(shadow.exists('ios/secret.txt'), isFalse);
        expect(shadow.skippedLinks, ['ios/secret.txt']);
      });
    }, skip: Platform.isWindows ? 'creating links needs privileges' : false);

    test('records the digest of every copied file', () async {
      fx.project.write('lib/a.dart', 'a');

      final shadow = await fx.create(['lib']);

      expect(shadow.baseline.keys, ['lib/a.dart']);
      expect(shadow.baseline['lib/a.dart'], startsWith('sha256:'));
    });

    test('accepts Windows style separators in the whitelist', () async {
      fx.project.write('android/app/build.gradle', 'g');

      final shadow = await fx.create([r'android\app\build.gradle']);

      expect(shadow.paths, ['android/app/build.gradle']);
      expect(shadow.read('android/app/build.gradle'), 'g');
    });

    test('dispose deletes the shadow, also when called twice', () async {
      fx.project.write('lib/a.dart', 'a');
      final shadow = await fx.create(['lib']);

      await shadow.dispose();
      await shadow.dispose();

      expect(shadow.root.existsSync(), isFalse);
      expect(fx.project.read('lib/a.dart'), 'a');
    });

    test('creates the shadow below the given temp parent', () async {
      final parent = Directory(p.join(fx.scratch.path, 'tmp'))..createSync();

      final shadow = await ShadowWorkspace.create(
        projectRoot: fx.project.root,
        paths: const [],
        tempParent: parent,
      );
      fx.track(shadow);

      expect(p.isWithin(parent.path, shadow.root.path), isTrue);
    });
  });
}
