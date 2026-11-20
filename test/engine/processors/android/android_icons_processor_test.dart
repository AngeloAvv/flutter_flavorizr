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
import 'dart:typed_data';

import 'package:flutter_flavorizr/src/engine/artifact.dart';
import 'package:flutter_flavorizr/src/engine/flavorizr_context.dart';
import 'package:flutter_flavorizr/src/engine/processors/android/android_icon_source.dart';
import 'package:flutter_flavorizr/src/engine/processors/android/android_icons_processor.dart';
import 'package:flutter_flavorizr/src/exception/file_not_found_exception.dart';
import 'package:flutter_flavorizr/src/exception/malformed_resource_exception.dart';
import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:test/test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../../../test_utils.dart';
import 'android_icon_source_test.dart' show gradientPng;
import 'posix_paths.dart';

const _sizes = {
  'mipmap-mdpi': 48,
  'mipmap-hdpi': 72,
  'mipmap-xhdpi': 96,
  'mipmap-xxhdpi': 144,
  'mipmap-xxxhdpi': 192,
};

const _adaptiveSizes = {
  'drawable-mdpi': 108,
  'drawable-hdpi': 162,
  'drawable-xhdpi': 216,
  'drawable-xxhdpi': 324,
  'drawable-xxxhdpi': 432,
};

String _flavor(String name, {String? appIcon, String? androidIcon}) =>
    '''
  $name:
    app:
      name: "App"
${appIcon == null ? '' : '      icon: "$appIcon"\n'}    android:
      applicationId: "com.example.$name"
${androidIcon == null ? '' : '      icon: "$androidIcon"\n'}''';

String _config(Iterable<String> flavors) => 'flavors:\n${flavors.join()}';

void main() {
  late Directory root;
  late Directory projectRoot;

  FlavorizrContext contextFor(String yaml, {Directory? workspace}) =>
      FlavorizrContext(
        config: FlavorizrConfig.parse(yaml),
        root: workspace ?? root,
        projectRoot: projectRoot,
        logger: TestUtils.quietLogger(),
      );

  File inRoot(String path) => File(p.join(root.path, path));

  void writeProject(String path, List<int> bytes) =>
      File(p.join(projectRoot.path, path))
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes);

  setUp(() {
    final temp = Directory.systemTemp.createTempSync('flavorizr_icons_');
    addTearDown(() => temp.deleteSync(recursive: true));

    root = Directory(p.join(temp.path, 'shadow'))..createSync();
    projectRoot = Directory(p.join(temp.path, 'project'))..createSync();
  });

  group('AndroidIconsProcessor', () {
    test(
      'is the `android:icons` processor, applied after the dummy assets',
      () {
        const processor = AndroidIconsProcessor();

        expect(processor.id, 'android:icons');
        expect(processor.dependsOn, isEmpty);
        expect(processor.after, {'android:dummyAssets'});
        expect(processor.requires, isEmpty);
      },
    );

    test('renders the launcher icon of a flavor at every density, read from '
        'the project and written to the workspace', () async {
      writeProject('assets/apple.png', gradientPng(256, 256));
      final ctx = contextFor(
        _config([_flavor('apple', appIcon: 'assets/apple.png')]),
      );

      await const AndroidIconsProcessor().apply(ctx);

      for (final MapEntry(key: folder, value: size) in _sizes.entries) {
        final file = inRoot(
          'android/app/src/apple/res/$folder/ic_launcher.png',
        );
        final icon = img.decodePng(file.readAsBytesSync())!;

        expect([icon.width, icon.height], [size, size], reason: folder);
      }
      expect(
        Directory(p.join(projectRoot.path, 'android')).existsSync(),
        isFalse,
        reason: 'nothing is written to the project',
      );
      expect(ctx.tracked.map((artifact) => artifact.path), [
        for (final folder in _sizes.keys)
          'android/app/src/apple/res/$folder/ic_launcher.png',
      ]);
      expect(ctx.tracked, everyElement(isA<ManagedArtifact>()));
      // What each icon is made from is declared, so that the lock records it.
      expect(
        ctx.tracked.map((artifact) => artifact.inputs),
        everyElement(matches(RegExp(r'^sha256:[0-9a-f]{64}$'))),
      );
    });

    test(
      'prefers the icon of the Android flavor to the one of the app',
      () async {
        writeProject('app.png', gradientPng(64, 64));
        writeProject('android.png', gradientPng(32, 32));
        final ctx = contextFor(
          _config([
            _flavor('apple', appIcon: 'app.png', androidIcon: 'android.png'),
          ]),
        );

        await const AndroidIconsProcessor().apply(ctx);

        final androidSource = AndroidIconSource.decode(
          File(p.join(projectRoot.path, 'android.png')).readAsBytesSync(),
          name: 'android.png',
        );
        expect(
          inRoot(
            'android/app/src/apple/res/mipmap-hdpi/ic_launcher.png',
          ).readAsBytesSync(),
          androidSource.renderPng(72, 72),
        );
      },
    );

    test('renders the same bytes on every run, and shares a source between '
        'flavors', () async {
      writeProject('icon.png', gradientPng(120, 90));
      final yaml = _config([
        _flavor('apple', appIcon: 'icon.png'),
        _flavor('banana', appIcon: 'icon.png'),
      ]);

      await const AndroidIconsProcessor().apply(contextFor(yaml));
      final first = {
        for (final file in root.listSync(recursive: true).whereType<File>())
          relativePosix(file.path, from: root.path): file.readAsBytesSync(),
      };

      final other = Directory(p.join(root.parent.path, 'other'))..createSync();
      await const AndroidIconsProcessor().apply(
        contextFor(yaml, workspace: other),
      );
      final second = {
        for (final file in other.listSync(recursive: true).whereType<File>())
          relativePosix(file.path, from: other.path): file.readAsBytesSync(),
      };

      expect(first.keys, hasLength(10));
      expect(second.keys, first.keys);
      for (final path in first.keys) {
        expect(second[path], first[path], reason: path);
      }
      expect(
        first['android/app/src/banana/res/mipmap-xhdpi/ic_launcher.png'],
        first['android/app/src/apple/res/mipmap-xhdpi/ic_launcher.png'],
      );
    });

    test(
      'produces nothing for flavors without an icon, or without Android',
      () async {
        final ctx = contextFor('''
flavors:
  apple:
    app:
      name: "Apple"
    android:
      applicationId: "com.example.apple"
  banana:
    app:
      name: "Banana"
      icon: "missing-but-not-for-android.png"
    ios:
      bundleId: "com.example.banana"
''');

        await const AndroidIconsProcessor().apply(ctx);

        expect(root.listSync(), isEmpty);
        expect(ctx.tracked, isEmpty);
      },
    );

    group('adaptive icons', () {
      const yaml = '''
flavors:
  apple:
    app:
      name: "Apple"
    android:
      applicationId: "com.example.apple"
      adaptiveIcon:
        foreground: "fg.png"
        background: "bg.png"
''';
      const withMonochrome = '''
flavors:
  apple:
    app:
      name: "Apple"
    android:
      applicationId: "com.example.apple"
      adaptiveIcon:
        foreground: "fg.png"
        background: "bg.png"
        monochrome: "mono.png"
''';

      setUp(() {
        writeProject('fg.png', gradientPng(120, 120));
        writeProject('bg.png', gradientPng(90, 90));
        writeProject('mono.png', gradientPng(60, 60));
      });

      test(
        'renders foreground and background at every density and the XML',
        () async {
          final ctx = contextFor(yaml);

          await const AndroidIconsProcessor().apply(ctx);

          for (final MapEntry(key: folder, value: size)
              in _adaptiveSizes.entries) {
            for (final name in ['foreground', 'background']) {
              final icon = img.decodePng(
                inRoot(
                  'android/app/src/apple/res/$folder/ic_launcher_$name.png',
                ).readAsBytesSync(),
              )!;

              expect([icon.width, icon.height], [size, size], reason: folder);
            }
            expect(
              inRoot(
                'android/app/src/apple/res/$folder/ic_launcher_monochrome.png',
              ).existsSync(),
              isFalse,
            );
          }
          expect(
            inRoot(
              'android/app/src/apple/res/mipmap-anydpi-v26/ic_launcher.xml',
            ).readAsStringSync(),
            '<?xml version="1.0" encoding="utf-8"?>\n'
            '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
            '<background android:drawable="@drawable/ic_launcher_background" />\n'
            '<foreground android:drawable="@drawable/ic_launcher_foreground" />\n'
            '</adaptive-icon>\n',
          );
          expect(ctx.tracked, hasLength(11));
          expect(
            ctx.tracked,
            everyElement(isA<ManagedArtifact>()),
            reason: 'generated from a source icon: managed and hashed',
          );
        },
      );

      test('renders the monochrome layer when there is one', () async {
        final ctx = contextFor(withMonochrome);

        await const AndroidIconsProcessor().apply(ctx);

        expect(
          inRoot(
            'android/app/src/apple/res/drawable-xxxhdpi/ic_launcher_monochrome.png',
          ).existsSync(),
          isTrue,
        );
        expect(
          inRoot(
            'android/app/src/apple/res/mipmap-anydpi-v26/ic_launcher.xml',
          ).readAsStringSync(),
          contains('ic_launcher_monochrome'),
        );
        expect(ctx.tracked, hasLength(16));
      });

      test('comes together with the launcher icon', () async {
        writeProject('icon.png', gradientPng(48, 48));
        final ctx = contextFor('''
flavors:
  apple:
    app:
      name: "Apple"
      icon: "icon.png"
    android:
      applicationId: "com.example.apple"
      adaptiveIcon:
        foreground: "fg.png"
        background: "bg.png"
''');

        await const AndroidIconsProcessor().apply(ctx);

        expect(ctx.tracked, hasLength(5 + 11));
      });
    });

    group('source icon failures leave the workspace untouched', () {
      Future<void> expectFailure(String yaml, Matcher matcher) async {
        await expectLater(
          const AndroidIconsProcessor().apply(contextFor(yaml)),
          throwsA(matcher),
        );
        expect(root.listSync(), isEmpty);
      }

      test('missing source', () async {
        await expectFailure(
          _config([_flavor('apple', appIcon: 'nope.png')]),
          isA<FileNotFoundException>(),
        );
      });

      test('a source that is not an image', () async {
        writeProject('icon.png', [1, 2, 3]);

        await expectFailure(
          _config([_flavor('apple', appIcon: 'icon.png')]),
          isA<MalformedResourceException>(),
        );
      });

      test('a source that is a directory', () async {
        Directory(p.join(projectRoot.path, 'icon.png')).createSync();

        await expectFailure(
          _config([_flavor('apple', appIcon: 'icon.png')]),
          isA<MalformedResourceException>(),
        );
      });

      test('a source that is an empty path', () async {
        await expectFailure(
          _config([_flavor('apple', appIcon: '')]),
          isA<MalformedResourceException>(),
        );
      });

      test('a source larger than any icon should be', () async {
        File(p.join(projectRoot.path, 'icon.png'))
          ..createSync()
          ..writeAsBytesSync(Uint8List(AndroidIconSource.maxBytes + 1));

        await expectFailure(
          _config([_flavor('apple', appIcon: 'icon.png')]),
          isA<MalformedResourceException>(),
        );
      });

      test(
        'a broken second flavor does not leave the first one behind',
        () async {
          writeProject('icon.png', gradientPng(48, 48));

          await expectFailure(
            _config([
              _flavor('apple', appIcon: 'icon.png'),
              _flavor('banana', appIcon: 'nope.png'),
            ]),
            isA<FileNotFoundException>(),
          );
        },
      );

      test('a source outside of the project', () async {
        File(
          p.join(projectRoot.parent.path, 'outside.png'),
        ).writeAsBytesSync(gradientPng(8, 8));

        await expectFailure(
          _config([_flavor('apple', appIcon: '../outside.png')]),
          isA<ArgumentError>(),
        );
      });

      test('an absolute source path', () async {
        final outside = File(p.join(projectRoot.parent.path, 'outside.png'))
          ..writeAsBytesSync(gradientPng(8, 8));

        await expectFailure(
          _config([_flavor('apple', appIcon: outside.path)]),
          isA<ArgumentError>(),
        );
      });

      test('a link inside the project that leads outside of it', () async {
        final outside = File(p.join(projectRoot.parent.path, 'outside.png'))
          ..writeAsBytesSync(gradientPng(8, 8));
        Link(p.join(projectRoot.path, 'icon.png')).createSync(outside.path);

        await expectFailure(
          _config([_flavor('apple', appIcon: 'icon.png')]),
          isA<ArgumentError>(),
        );
      });

      test('a flavor name that is not a single directory name', () async {
        writeProject('icon.png', gradientPng(48, 48));

        for (final name in ['../main', 'a/b', r'a\b', '..']) {
          await expectFailure(
            _config([_flavor("'$name'", appIcon: 'icon.png')]),
            isA<ArgumentError>(),
          );
        }
      });
    });

    test('follows a link that stays inside the project', () async {
      writeProject('real/icon.png', gradientPng(48, 48));
      Link(
        p.join(projectRoot.path, 'icon.png'),
      ).createSync(p.join(projectRoot.path, 'real/icon.png'));
      final ctx = contextFor(_config([_flavor('apple', appIcon: 'icon.png')]));

      await const AndroidIconsProcessor().apply(ctx);

      expect(ctx.tracked, hasLength(5));
    });

    test('never writes outside of the workspace', () async {
      writeProject('icon.png', gradientPng(48, 48));
      final before = Directory.current.path;

      await const AndroidIconsProcessor().apply(
        contextFor(_config([_flavor('apple', appIcon: 'icon.png')])),
      );

      expect(Directory.current.path, before);
      expect(projectRoot.listSync().map((e) => p.basename(e.path)), [
        'icon.png',
      ]);
    });
  });
}
