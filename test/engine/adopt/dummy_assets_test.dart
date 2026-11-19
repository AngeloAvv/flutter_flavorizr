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
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// The project flavorized by 2.6.0 that the parity harness recorded. Its binary
/// files are kept as `<file>.sha256`: the hash of what 2.6.0 wrote, which is an
/// independent source of truth for the table.
final _golden = Directory('tool/parity/golden/2.6.0/tree');

String _recorded(String path) =>
    File(p.join(_golden.path, '$path.sha256')).readAsStringSync().trim();

/// The paths (of the project) of the binary files recorded below [folder].
Iterable<String> _recordedBelow(String folder) =>
    Directory(p.join(_golden.path, folder))
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.sha256'))
        .map(
          (file) => p.posix
              .joinAll(p.split(p.relative(file.path, from: _golden.path)))
              .replaceFirst(RegExp(r'\.sha256$'), ''),
        );

void main() {
  group('DummyAssets.v2', () {
    test(
      'has the hash of every dummy launcher icon 2.6.0 wrote for Android',
      () {
        final paths = DummyAssets.v2.flavorPaths('banana', platform: 'android');

        expect(paths.keys, hasLength(5));

        for (final MapEntry(key: path, value: hash) in paths.entries) {
          expect(hash, _recorded(path), reason: path);
        }
      },
    );

    test(
      'has the hash of every dummy icon and launch image 2.6.0 wrote for iOS',
      () {
        final paths = DummyAssets.v2.flavorPaths('banana', platform: 'ios');
        final recorded = {
          ..._recordedBelow(
            'ios/Runner/Assets.xcassets/AppIcon-banana.appiconset',
          ),
          ..._recordedBelow(
            'ios/Runner/Assets.xcassets/bananaLaunchImage.imageset',
          ),
        };

        expect(recorded, isNotEmpty);

        for (final path in recorded) {
          expect(paths[path], _recorded(path), reason: path);
        }
      },
    );

    test('has the hash of every dummy icon 2.6.0 wrote for macOS', () {
      final paths = DummyAssets.v2.flavorPaths('apple', platform: 'macos');
      final recorded = _recordedBelow(
        'macos/Runner/Assets.xcassets/AppIcon-apple.appiconset',
      );

      expect(recorded, hasLength(7));

      for (final path in recorded) {
        expect(paths[path], _recorded(path), reason: path);
      }
    });

    test('names the files of a flavor after the flavor', () {
      final apple = DummyAssets.v2.flavorPaths('apple');

      expect(
        apple.keys,
        containsAll([
          'android/app/src/apple/res/mipmap-hdpi/ic_launcher.png',
          'ios/Runner/Assets.xcassets/AppIcon-apple.appiconset/Icon-App-20x20@1x.png',
          'macos/Runner/Assets.xcassets/AppIcon-apple.appiconset/app_icon_16.png',
        ]),
      );
      expect(apple.keys.where((path) => path.contains('banana')), isEmpty);
    });

    test('has nothing for a platform that has no dummy assets', () {
      expect(DummyAssets.v2.flavorPaths('apple', platform: 'linux'), isEmpty);
    });
  });

  group('DummyAssets', () {
    final table = DummyAssets({
      'android/res/mipmap-hdpi/ic_launcher.png': DummyAssets.hashOf(
        utf8.encode('dummy'),
      ),
    });

    test('places the assets of the table where 2.x put them', () {
      expect(table.flavorPaths('apple'), {
        'android/app/src/apple/res/mipmap-hdpi/ic_launcher.png':
            DummyAssets.hashOf(utf8.encode('dummy')),
      });
    });

    test('a hash is the sha256 in hex', () {
      expect(
        DummyAssets.hashOf(utf8.encode('abc')),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
    });
  });
}
