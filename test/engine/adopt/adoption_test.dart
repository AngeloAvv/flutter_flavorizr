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

import 'package:flutter_flavorizr/src/engine/adopt/adoption.dart';
import 'package:flutter_flavorizr/src/engine/adopt/dummy_assets.dart';
import 'package:flutter_flavorizr/src/engine/artifact.dart';
import 'package:flutter_flavorizr/src/engine/lock/flavorizr_lock.dart';
import 'package:flutter_flavorizr/src/engine/ownership.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

String _hash(Artifact artifact, List<int> bytes) =>
    '${artifact.ownership.name}:${utf8.decode(bytes)}';

final _dummies = DummyAssets({
  'android/res/mipmap-hdpi/ic_launcher.png': DummyAssets.hashOf(
    utf8.encode('dummy'),
  ),
});

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('flavorizr_adoption_');
    addTearDown(() => root.deleteSync(recursive: true));
  });

  void write(String path, String content) {
    final file = File(p.join(root.path, path));

    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
  }

  Future<Adoption> adopt({
    Map<String, Iterable<Artifact>> produced = const {},
    Iterable<String> androidFlavors = const [],
    Map<String, String> flavors = const {},
    Set<String>? available,
  }) => adoptProject(
    projectRoot: root,
    produced: produced,
    androidFlavors: androidFlavors,
    flavors: flavors,
    availableProcessors: available ?? produced.keys.toSet(),
    flavorizrVersion: '3.0.0',
    hasher: _hash,
    dummyAssets: _dummies,
  );

  group('the files a processor produces', () {
    test('are recorded with the hash of what the disk holds', () async {
      write('lib/flavors.dart', 'from 2.x');

      final adoption = await adopt(
        produced: {
          'flutter:flavors': [const Artifact.managed('lib/flavors.dart')],
        },
      );

      expect(
        adoption.lock.processors['flutter:flavors']!.files['lib/flavors.dart'],
        LockedFile(ownership: Ownership.managed, hash: 'managed:from 2.x'),
      );
    });

    test('are recorded by the owned part when the file is patched', () async {
      write('ios/Runner/Info.plist', 'plist');

      final adoption = await adopt(
        produced: {
          'ios:plist': [const Artifact.patched('ios/Runner/Info.plist')],
        },
      );

      expect(
        adoption.lock.processors['ios:plist']!.files['ios/Runner/Info.plist'],
        LockedFile(ownership: Ownership.patched, hash: 'patched:plist'),
      );
    });

    test('are not recorded when the project does not have them', () async {
      final adoption = await adopt(
        produced: {
          'flutter:flavors': [const Artifact.managed('lib/flavors.dart')],
        },
      );

      expect(adoption.lock.processors, isEmpty);
      expect(adoption.recorded, isEmpty);
    });

    test('are not recorded when they are local or scaffold', () async {
      write('.vscode/launch.json', '{}');
      write('lib/main.dart', 'main');

      final adoption = await adopt(
        produced: {
          'ide:config': [const Artifact.local('.vscode/launch.json')],
          'flutter:main': [const Artifact.scaffold('lib/main.dart')],
        },
      );

      expect(adoption.lock.processors, isEmpty);
    });

    test('are recorded under the processor that produces them', () async {
      write('a.txt', 'a');
      write('b.txt', 'b');

      final adoption = await adopt(
        produced: {
          'one': [const Artifact.managed('a.txt')],
          'two': [const Artifact.managed('b.txt')],
        },
      );

      expect(adoption.recorded, {
        'one': ['a.txt'],
        'two': ['b.txt'],
      });
    });
  });

  group('the dummy icons of 2.x', () {
    const icon = 'android/app/src/apple/res/mipmap-hdpi/ic_launcher.png';

    test('that were never touched are managed', () async {
      write(icon, 'dummy');

      final adoption = await adopt(
        produced: {'android:icons': const []},
        androidFlavors: ['apple'],
      );

      expect(
        adoption.lock.processors['android:icons']!.files[icon],
        LockedFile(ownership: Ownership.managed, hash: 'managed:dummy'),
      );
    });

    test('that the user replaced are theirs, and not recorded', () async {
      write(icon, 'my own icon');

      final adoption = await adopt(
        produced: {'android:icons': const []},
        androidFlavors: ['apple'],
      );

      expect(adoption.lock.processors, isEmpty);
      expect(adoption.userOwned, [icon]);
    });

    test('are looked for in the flavors of the project and the ones declared '
        'as historical alike', () async {
      write(icon, 'dummy');
      write('android/app/src/cherry/res/mipmap-hdpi/ic_launcher.png', 'dummy');

      final adoption = await adopt(
        produced: {'android:icons': const []},
        androidFlavors: ['apple', 'cherry'],
      );

      expect(adoption.lock.processors['android:icons']!.files.keys, [
        icon,
        'android/app/src/cherry/res/mipmap-hdpi/ic_launcher.png',
      ]);
    });

    test('are left alone when the run does not make icons', () async {
      write(icon, 'dummy');

      final adoption = await adopt(
        produced: {'flutter:flavors': const []},
        androidFlavors: ['apple'],
      );

      expect(adoption.lock.processors, isEmpty);
      expect(adoption.userOwned, isEmpty);
    });

    test('that the processor makes anyway are recorded once', () async {
      write(icon, 'dummy');

      final adoption = await adopt(
        produced: {
          'android:icons': [const Artifact.managed(icon)],
        },
        androidFlavors: ['apple'],
      );

      expect(adoption.recorded['android:icons'], [icon]);
    });

    test(
      'of a flavor with a name that is no folder are never looked for',
      () async {
        write('android/app/src/main/res/mipmap-hdpi/ic_launcher.png', 'dummy');

        final adoption = await adopt(
          produced: {'android:icons': const []},
          androidFlavors: ['../main/../../../x', 'a/b'],
        );

        expect(adoption.lock.processors, isEmpty);
      },
    );
  });

  group('the flavors', () {
    test('are recorded by a run of all the processors', () async {
      final adoption = await adopt(
        produced: {'one': const [], 'two': const []},
        flavors: {'apple': 'hash'},
      );

      expect(adoption.lock.flavors, {'apple': 'hash'});
      expect(adoption.lock.flavorizrVersion, '3.0.0');
    });

    test('are not recorded by a run of some of them', () async {
      final adoption = await adopt(
        produced: {'one': const []},
        flavors: {'apple': 'hash'},
        available: {'one', 'two'},
      );

      expect(adoption.lock.flavors, isEmpty);
    });
  });
}
