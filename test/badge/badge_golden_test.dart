/*
 * Copyright (c) 2024 Angelo Cassano
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

import 'package:flutter_flavorizr/src/engine/flavorizr_context.dart';
import 'package:flutter_flavorizr/src/engine/processors/android/android_icons_processor.dart';
import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:flutter_flavorizr/src/processors/ios/icons/ios_icons_processor.dart';
import 'package:flutter_flavorizr/src/processors/macos/icons/macos_icons_processor.dart';
import 'package:flutter_flavorizr/src/processors/windows/icons/windows_icons_processor.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../test_utils.dart';

/// The golden images of the badge: one sheet for each platform, with the icons
/// the processors write at every size, side by side, from the smallest to the
/// largest. They are compared pixel by pixel.
///
/// To make them again after a change of the look of the badge, run the tests
/// with `UPDATE_GOLDENS=1` and look at the sheets in `test/badge/golden`.
const _goldens = 'test/badge/golden';

/// An icon of 1024 px: flat colours, so that the sheets are small as files.
/// [transparent] is a foreground layer: a disc on nothing.
img.Image _source({required bool transparent}) {
  final image = img.Image(width: 1024, height: 1024, numChannels: 4);

  img.fill(
    image,
    color: transparent
        ? img.ColorRgba8(0, 0, 0, 0)
        : img.ColorRgba8(33, 150, 243, 255),
  );
  img.fillCircle(
    image,
    x: 512,
    y: 512,
    radius: transparent ? 300 : 380,
    color: img.ColorRgba8(255, 255, 255, 255),
  );
  img.fillCircle(
    image,
    x: 512,
    y: 400,
    radius: 120,
    color: img.ColorRgba8(255, 193, 7, 255),
  );

  return image;
}

/// The [icons], from the smallest, side by side on a grey ground.
img.Image _sheet(Iterable<img.Image> icons) {
  final sorted = icons.toList()..sort((a, b) => a.width - b.width);
  final width = sorted.fold(8, (sum, icon) => sum + icon.width + 8);
  final height = sorted.last.height + 16;
  final sheet = img.Image(width: width, height: height, numChannels: 4);

  img.fill(sheet, color: img.ColorRgba8(128, 128, 128, 255));

  var x = 8;

  for (final icon in sorted) {
    img.compositeImage(sheet, icon, dstX: x, dstY: 8);
    x += icon.width + 8;
  }

  return sheet;
}

void main() {
  late Directory originalDir;

  setUp(() => originalDir = Directory.current);
  tearDown(() => Directory.current = originalDir);

  /// That [sheet] is the golden image called [name].
  void expectGolden(img.Image sheet, String name) {
    final file = File(p.join(originalDir.path, _goldens, '$name.png'));

    if (Platform.environment['UPDATE_GOLDENS'] == '1') {
      file
        ..createSync(recursive: true)
        ..writeAsBytesSync(img.encodePng(sheet, level: 9));
    }

    expect(file.existsSync(), isTrue, reason: 'no golden image `$name`');

    final golden = img.decodePng(file.readAsBytesSync())!;

    expect([sheet.width, sheet.height], [golden.width, golden.height]);
    expect(
      sheet.convert(numChannels: 4).toUint8List(),
      golden.convert(numChannels: 4).toUint8List(),
      reason: '`$name` is not the golden image: see UPDATE_GOLDENS',
    );
  }

  /// Runs [body] in a project that has `assets/icon.png`, of 1024 px.
  Future<void> inProject(
    Future<void> Function(Directory project) body, {
    bool transparent = false,
  }) => TestUtils.withTempDir((dir) async {
    File(p.join(dir.path, 'assets/icon.png'))
      ..createSync(recursive: true)
      ..writeAsBytesSync(img.encodePng(_source(transparent: transparent)));
    Directory.current = dir;

    try {
      await body(dir);
    } finally {
      Directory.current = originalDir;
    }
  });

  Iterable<img.Image> pngsBelow(String folder) => [
    for (final file in Directory(folder).listSync(recursive: true))
      if (file is File && file.path.endsWith('.png'))
        img.decodePng(file.readAsBytesSync())!,
  ];

  /// One of each size.
  Iterable<img.Image> distinct(Iterable<img.Image> icons) =>
      {for (final icon in icons) icon.width: icon}.values;

  /// The configuration of a flavor with a [badge], whose icon is the one of
  /// the project, for a [platform] of the Darwin and Windows.
  String yaml(String platform, String badge) =>
      '''
flavors:
  dev:
    app:
      name: "App"
    badge: $badge
    $platform:
${platform == 'windows' ? '' : '      bundleId: "com.example.dev"\n'}      icon: assets/icon.png
''';

  group('the golden images of the badge', () {
    test('Android legacy mipmaps, 48 to 192 px', () async {
      await inProject((project) async {
        final root = Directory(p.join(project.path, 'out'))..createSync();

        await const AndroidIconsProcessor().apply(
          FlavorizrContext(
            config: FlavorizrConfig.parse('''
flavors:
  dev:
    app:
      name: "App"
    badge: { label: DEV }
    android:
      applicationId: "com.example.dev"
      icon: assets/icon.png
'''),
            root: root,
            projectRoot: project,
            logger: TestUtils.quietLogger(),
          ),
        );

        final icons = pngsBelow(p.join(root.path, 'android'));

        expect(icons.map((icon) => icon.width).toSet(), {48, 72, 96, 144, 192});
        expectGolden(_sheet(icons), 'android_legacy');
      });
    });

    test(
      'Android adaptive foregrounds, 108 to 432 px, in the safe zone',
      () async {
        await inProject(transparent: true, (project) async {
          final root = Directory(p.join(project.path, 'out'))..createSync();

          await const AndroidIconsProcessor().apply(
            FlavorizrContext(
              config: FlavorizrConfig.parse('''
flavors:
  dev:
    app:
      name: "App"
    badge: { label: STAGING, color: "#FFEB3B" }
    android:
      applicationId: "com.example.dev"
      adaptiveIcon:
        foreground: assets/icon.png
        background: assets/icon.png
'''),
              root: root,
              projectRoot: project,
              logger: TestUtils.quietLogger(),
            ),
          );

          final foregrounds = [
            for (final file in Directory(
              p.join(root.path, 'android'),
            ).listSync(recursive: true))
              if (file is File &&
                  file.path.endsWith('ic_launcher_foreground.png'))
                img.decodePng(file.readAsBytesSync())!,
          ];

          expect(foregrounds.map((icon) => icon.width).toSet(), {
            108,
            162,
            216,
            324,
            432,
          });
          expectGolden(_sheet(foregrounds), 'android_adaptive');
        });
      },
    );

    test('iOS icons, 20 to 1024 px', () async {
      await inProject((project) async {
        await IOSIconsProcessor(
          config: FlavorizrConfig.parse(
            yaml('ios', '{ label: QA, color: "#1E88E5" }'),
          ),
          logger: TestUtils.quietLogger(),
        ).execute();

        final icons = distinct(pngsBelow('ios'));

        expect(icons.length, 13);
        expectGolden(_sheet(icons), 'ios');
      });
    });

    test('macOS icons, 16 to 1024 px', () async {
      await inProject((project) async {
        await MacOSIconsProcessor(
          config: FlavorizrConfig.parse(yaml('macos', '{ label: BETA }')),
          logger: TestUtils.quietLogger(),
        ).execute();

        final icons = distinct(pngsBelow('macos'));

        expect(icons.map((icon) => icon.width).toSet(), {
          16,
          32,
          64,
          128,
          256,
          512,
          1024,
        });
        expectGolden(_sheet(icons), 'macos');
      });
    });

    test('Windows .ico, 16 to 256 px, with a label that is cut', () async {
      await inProject((project) async {
        await WindowsIconsProcessor(
          config: FlavorizrConfig.parse(
            yaml('windows', '{ label: PRODUCTION, color: "#6D4C41" }'),
          ),
          logger: TestUtils.quietLogger(),
        ).execute();

        final bytes = File(
          'windows/runner/resources/dev.ico',
        ).readAsBytesSync();
        final decoder = img.IcoDecoder();
        final info = decoder.startDecode(bytes)!;
        final frames = [
          for (var i = 0; i < info.numFrames; i++)
            decoder.decode(bytes, frame: i)!,
        ];

        expect(frames.map((icon) => icon.width).toSet(), {16, 32, 48, 256});
        expectGolden(_sheet(frames), 'windows');
      });
    });
  });
}
