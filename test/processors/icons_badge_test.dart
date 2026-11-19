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

import 'package:flutter_flavorizr/src/badge/badge_color.dart';
import 'package:flutter_flavorizr/src/badge/badge_palette.dart';
import 'package:flutter_flavorizr/src/badge/badge_renderer.dart';
import 'package:flutter_flavorizr/src/badge/badge_source_icon.dart';
import 'package:flutter_flavorizr/src/badge/resolved_badge.dart';
import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:flutter_flavorizr/src/processors/commons/ico_encoder_processor.dart';
import 'package:flutter_flavorizr/src/processors/commons/image_resizer_processor.dart';
import 'package:flutter_flavorizr/src/processors/ios/icons/ios_icons_processor.dart';
import 'package:flutter_flavorizr/src/processors/macos/icons/macos_icons_processor.dart';
import 'package:flutter_flavorizr/src/processors/windows/icons/windows_icons_processor.dart';
import 'package:flutter_flavorizr/src/models/commons/size.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../engine/processors/android/android_icon_source_test.dart'
    show gradientPng;
import '../test_utils.dart';

final _badge = ResolvedBadge(
  label: 'DEV',
  color: const BadgeColor(0xE5, 0x39, 0x35),
);

String _yaml(String platform, {String badge = '', String icon = ''}) =>
    '''
$badge
flavors:
  dev:
    app:
      name: "App"
$icon    $platform:
      ${platform == 'windows' ? '{}' : 'bundleId: "com.example.dev"'}
''';

void main() {
  late Directory originalDir;

  setUp(() => originalDir = Directory.current);
  tearDown(() => Directory.current = originalDir);

  /// Runs [body] in a project that has an icon of 600 px (or none), as the
  /// current directory, which is where the processors look for their files.
  Future<void> inProject(
    Future<void> Function(Directory dir) body, {
    bool withIcon = true,
  }) => TestUtils.withTempDir((dir) async {
    if (withIcon) {
      File(p.join(dir.path, 'assets/icon.png'))
        ..createSync(recursive: true)
        ..writeAsBytesSync(gradientPng(600, 600));
    }
    Directory.current = dir;

    try {
      await body(dir);
    } finally {
      // The directory is deleted when the body is done.
      Directory.current = originalDir;
    }
  });

  img.Image decoded(String path) =>
      img.decodePng(File(path).readAsBytesSync())!;

  /// That the badge is on the bottom of [icon]: the corner of it has the colour
  /// of the band, [color] unless it is the default of the flavor `dev`.
  void expectBadged(img.Image icon, {BadgeColor? color, String? reason}) {
    final band = color ?? _badge.color;
    final corner = icon.getPixel(0, icon.height - 1);

    expect(
      [corner.r, corner.g, corner.b],
      [band.red, band.green, band.blue],
      reason: reason,
    );
  }

  group('ImageResizerProcessor', () {
    test('draws the badge on the icon at its size', () async {
      await inProject((dir) async {
        final destination = p.join(dir.path, 'out.png');

        ImageResizerProcessor(
          'assets/icon.png',
          destination,
          const Size(120, 120),
          badge: _badge,
          config: FlavorizrConfig.parse('flavors: {}'),
          logger: TestUtils.quietLogger(),
        ).execute();

        final icon = decoded(destination);
        final band = badgeBand(120, BadgeArea.full);

        expect([icon.width, icon.height], [120, 120]);
        expectBadged(icon);
        // Nothing of the icon above the band was touched.
        final plain = img.copyResize(
          decoded('assets/icon.png'),
          width: 120,
          height: 120,
          interpolation: img.Interpolation.average,
        );

        for (var y = 0; y < band.top; y++) {
          final a = icon.getPixel(60, y);
          final b = plain.getPixel(60, y);

          expect([a.r, a.g, a.b], [b.r, b.g, b.b]);
        }
      });
    });
  });

  group('IcoEncoderProcessor', () {
    test('draws the badge on every size of the .ico', () async {
      await inProject((dir) async {
        final destination = p.join(dir.path, 'app.ico');

        IcoEncoderProcessor(
          'assets/icon.png',
          destination,
          badge: _badge,
          config: FlavorizrConfig.parse('flavors: {}'),
          logger: TestUtils.quietLogger(),
        ).execute();

        final bytes = File(destination).readAsBytesSync();
        final decoder = img.IcoDecoder();
        final info = decoder.startDecode(bytes)!;

        expect(info.numFrames, 4);

        for (var i = 0; i < info.numFrames; i++) {
          final frame = decoder.decode(bytes, frame: i)!;

          expectBadged(frame, reason: '${frame.width}');
        }
      });
    });
  });

  group('the icons processors of the Darwin and Windows platforms', () {
    test('badge a flavor with an icon, at the size of each file', () async {
      await inProject((dir) async {
        await IOSIconsProcessor(
          config: FlavorizrConfig.parse(
            _yaml(
              'ios',
              badge: 'badge: true',
              icon: '      icon: assets/icon.png\n',
            ),
          ),
          logger: TestUtils.quietLogger(),
        ).execute();

        final set = 'ios/Runner/Assets.xcassets/AppIcon-dev.appiconset';
        final marketing = decoded(p.join(set, 'Icon-App-1024x1024@1x.png'));
        final small = decoded(p.join(set, 'Icon-App-20x20@2x.png'));

        expect([marketing.width, small.width], [1024, 40]);
        expectBadged(marketing, color: defaultBadgeColor('dev'));
        expectBadged(small, color: defaultBadgeColor('dev'));
      });
    });

    test('make the icons of a flavor with a badge and no icon, from the one of '
        'the root', () async {
      await inProject((dir) async {
        await MacOSIconsProcessor(
          config: FlavorizrConfig.parse(
            _yaml('macos', badge: 'badge: true\nicon: assets/icon.png'),
          ),
          logger: TestUtils.quietLogger(),
        ).execute();

        await WindowsIconsProcessor(
          config: FlavorizrConfig.parse(
            _yaml('windows', badge: 'badge: true\nicon: assets/icon.png'),
          ),
          logger: TestUtils.quietLogger(),
        ).execute();

        final set = 'macos/Runner/Assets.xcassets/AppIcon-dev.appiconset';

        expectBadged(
          decoded(p.join(set, 'app_icon_512.png')),
          color: defaultBadgeColor('dev'),
        );
        expect(File('windows/runner/resources/dev.ico').existsSync(), isTrue);
      });
    });

    test('make nothing for a flavor with no badge and no icon', () async {
      await inProject((dir) async {
        await IOSIconsProcessor(
          config: FlavorizrConfig.parse(_yaml('ios')),
          logger: TestUtils.quietLogger(),
        ).execute();

        expect(Directory('ios').existsSync(), isFalse);
      });
    });

    test('keep the icon of a flavor that has no badge as it is', () async {
      await inProject((dir) async {
        await IOSIconsProcessor(
          config: FlavorizrConfig.parse(
            _yaml('ios', icon: '      icon: assets/icon.png\n'),
          ),
          logger: TestUtils.quietLogger(),
        ).execute();

        final set = 'ios/Runner/Assets.xcassets/AppIcon-dev.appiconset';
        final icon = decoded(p.join(set, 'Icon-App-1024x1024@1x.png'));
        final plain = img.copyResize(
          decoded('assets/icon.png'),
          width: 1024,
          height: 1024,
          interpolation: img.Interpolation.average,
        );

        expect(icon.toUint8List(), plain.toUint8List());
      });
    });

    test('fail with a hint when there is no icon of 512 px', () async {
      await inProject((dir) async {
        // The source is chosen when the processor is built.
        expect(
          () => IOSIconsProcessor(
            config: FlavorizrConfig.parse(_yaml('ios', badge: 'badge: true')),
            logger: TestUtils.quietLogger(),
          ),
          throwsA(isA<BadgeSourceIconException>()),
        );
      }, withIcon: false);
    });
  });
}
