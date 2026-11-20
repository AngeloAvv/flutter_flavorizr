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
  'ios/Assets.xcassets/AppIcon.appiconset/Contents.json': DummyAssets.hashOf(
    utf8.encode('dummy'),
  ),
  'ios/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png':
      DummyAssets.hashOf(utf8.encode('dummy')),
  'ios/Assets.xcassets/LaunchImage.imageset/LaunchImage.png':
      DummyAssets.hashOf(utf8.encode('dummy')),
  'ios/LaunchScreen.storyboard': DummyAssets.hashOf(utf8.encode('dummy')),
  'macos/Assets.xcassets/AppIcon.appiconset/app_icon_16.png':
      DummyAssets.hashOf(utf8.encode('dummy')),
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
    Iterable<String> iosFlavors = const [],
    Iterable<String> macosFlavors = const [],
    Map<String, String> flavors = const {},
    Set<String>? available,
    Set<String> historical = const {},
  }) => adoptProject(
    projectRoot: root,
    produced: produced,
    androidFlavors: androidFlavors,
    iosFlavors: iosFlavors,
    macosFlavors: macosFlavors,
    historicalFlavors: historical,
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

    test('of a historical flavor are told by their hash alone, even when the '
        'processor makes them from the settings of another flavor', () async {
      const cherry = 'android/app/src/cherry/res/mipmap-hdpi/ic_launcher.png';

      write(icon, 'my own icon');
      write(cherry, 'my own icon');

      final adoption = await adopt(
        produced: {
          // `cherry` has the icon source of `apple`, so the processor makes it.
          'android:icons': [
            const Artifact.managed(icon),
            const Artifact.managed(cherry),
          ],
        },
        androidFlavors: ['apple', 'cherry'],
        historical: {'cherry'},
      );

      expect(adoption.recorded['android:icons'], [icon]);
      expect(adoption.userOwned, [cherry]);
    });

    test(
      'of a historical flavor that were never touched are managed',
      () async {
        const cherry = 'android/app/src/cherry/res/mipmap-hdpi/ic_launcher.png';

        write(cherry, 'dummy');

        final adoption = await adopt(
          produced: {
            'android:icons': [const Artifact.managed(cherry)],
          },
          androidFlavors: ['cherry'],
          historical: {'cherry'},
        );

        expect(adoption.recorded['android:icons'], [cherry]);
        expect(adoption.userOwned, isEmpty);
      },
    );

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

  group('the dummy icons of 2.x on iOS and macOS', () {
    const iosSet = 'ios/Runner/Assets.xcassets/AppIcon-apple.appiconset';
    const macosSet = 'macos/Runner/Assets.xcassets/AppIcon-apple.appiconset';

    test('that were never touched are managed by the icons processor of '
        'their platform', () async {
      write('$iosSet/Contents.json', 'dummy');
      write('$iosSet/Icon-App-20x20@2x.png', 'dummy');
      write('$macosSet/app_icon_16.png', 'dummy');

      final adoption = await adopt(
        produced: {'ios:icons': const [], 'macos:icons': const []},
        iosFlavors: ['apple'],
        macosFlavors: ['apple'],
      );

      expect(adoption.recorded, {
        'ios:icons': ['$iosSet/Contents.json', '$iosSet/Icon-App-20x20@2x.png'],
        'macos:icons': ['$macosSet/app_icon_16.png'],
      });
      expect(
        adoption.lock.processors['ios:icons']!.files['$iosSet/Contents.json'],
        LockedFile(ownership: Ownership.managed, hash: 'managed:dummy'),
      );
    });

    test('that the user replaced are theirs, and not recorded', () async {
      write('$iosSet/Icon-App-20x20@2x.png', 'my own icon');
      write('$macosSet/app_icon_16.png', 'my own icon');

      final adoption = await adopt(
        produced: {'ios:icons': const [], 'macos:icons': const []},
        iosFlavors: ['apple'],
        macosFlavors: ['apple'],
      );

      expect(adoption.lock.processors, isEmpty);
      expect(adoption.userOwned, [
        '$iosSet/Icon-App-20x20@2x.png',
        '$macosSet/app_icon_16.png',
      ]);
    });

    test('are only looked for by the processor of their platform, and only in '
        'the flavors of it', () async {
      write('$iosSet/Contents.json', 'dummy');
      write('$macosSet/app_icon_16.png', 'dummy');

      final adoption = await adopt(
        produced: {'ios:icons': const [], 'macos:icons': const []},
        iosFlavors: ['banana'],
        macosFlavors: const [],
      );

      expect(adoption.lock.processors, isEmpty);
      expect(adoption.userOwned, isEmpty);
    });

    test('are left alone when the run does not make icons', () async {
      write('$iosSet/Contents.json', 'dummy');

      final adoption = await adopt(
        produced: {'ios:plist': const []},
        iosFlavors: ['apple'],
      );

      expect(adoption.lock.processors, isEmpty);
      expect(adoption.userOwned, isEmpty);
    });

    test(
      'are not the launch images and storyboards, which are not icons',
      () async {
        const launch =
            'ios/Runner/Assets.xcassets/appleLaunchImage.imageset/LaunchImage.png';

        write(launch, 'dummy');
        write('ios/Runner/appleLaunchScreen.storyboard', 'dummy');

        final adoption = await adopt(
          produced: {'ios:icons': const []},
          iosFlavors: ['apple'],
        );

        expect(adoption.lock.processors, isEmpty);
        expect(adoption.userOwned, isEmpty);
      },
    );

    test('of a historical flavor are told by their hash alone, even when the '
        'processor makes them from the settings of another flavor', () async {
      const cherry =
          'ios/Runner/Assets.xcassets/AppIcon-cherry.appiconset/Contents.json';

      write('$iosSet/Contents.json', 'my own icons');
      write(cherry, 'my own icons');

      final adoption = await adopt(
        produced: {
          'ios:icons': [
            const Artifact.managed('$iosSet/Contents.json'),
            const Artifact.managed(cherry),
          ],
        },
        iosFlavors: ['apple', 'cherry'],
        historical: {'cherry'},
      );

      expect(adoption.recorded['ios:icons'], ['$iosSet/Contents.json']);
      expect(adoption.userOwned, [cherry]);
    });

    test('of a historical flavor that were never touched are managed', () async {
      const cherry =
          'macos/Runner/Assets.xcassets/AppIcon-cherry.appiconset/app_icon_16.png';

      write(cherry, 'dummy');

      final adoption = await adopt(
        produced: {
          'macos:icons': [const Artifact.managed(cherry)],
        },
        macosFlavors: ['cherry'],
        historical: {'cherry'},
      );

      expect(adoption.recorded['macos:icons'], [cherry]);
    });

    test('that the processor makes anyway are recorded once', () async {
      write('$iosSet/Contents.json', 'dummy');

      final adoption = await adopt(
        produced: {
          'ios:icons': [const Artifact.managed('$iosSet/Contents.json')],
        },
        iosFlavors: ['apple'],
      );

      expect(adoption.recorded['ios:icons'], ['$iosSet/Contents.json']);
    });

    test(
      'of a flavor with a name that is no folder are never looked for',
      () async {
        write(
          'ios/Runner/Assets.xcassets/AppIcon-.appiconset/Contents.json',
          'dummy',
        );

        final adoption = await adopt(
          produced: {'ios:icons': const []},
          iosFlavors: ['../x', 'a/b', ''],
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
