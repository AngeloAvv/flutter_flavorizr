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
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_flavorizr/src/badge/badge_palette.dart';
import 'package:flutter_flavorizr/src/badge/badge_renderer.dart';
import 'package:flutter_flavorizr/src/badge/badge_source_icon.dart';
import 'package:flutter_flavorizr/src/engine/flavorizr_context.dart';
import 'package:flutter_flavorizr/src/engine/processors/android/android_icons_processor.dart';
import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:image/image.dart' as img;
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'android_icon_source_test.dart' show gradientPng;

/// A logger that keeps the warnings it is asked to print.
class _RecordingLogger extends Logger {
  final List<String?> warnings = [];

  _RecordingLogger() : super(level: Level.quiet);

  @override
  void warn(String? message, {String tag = 'WARN', LogStyle? style}) =>
      warnings.add(message);
}

String _config({
  String rootBadge = '',
  String rootIcon = '',
  String flavorBadge = '',
  String flavorIcon = '      icon: "assets/dev.png"\n',
  String adaptive = '',
}) =>
    '''
$rootBadge$rootIcon
flavors:
  dev:
    app:
      name: "App"
$flavorBadge    android:
      applicationId: "com.example.dev"
$flavorIcon$adaptive''';

const _adaptive = '''
      adaptiveIcon:
        foreground: "assets/fg.png"
        background: "assets/bg.png"
        monochrome: "assets/mono.png"
''';

const _legacyFolders = [
  'mipmap-mdpi',
  'mipmap-hdpi',
  'mipmap-xhdpi',
  'mipmap-xxhdpi',
  'mipmap-xxxhdpi',
];

const _adaptiveFolders = [
  'drawable-mdpi',
  'drawable-hdpi',
  'drawable-xhdpi',
  'drawable-xxhdpi',
  'drawable-xxxhdpi',
];

void main() {
  late Directory root;
  late Directory projectRoot;
  late _RecordingLogger logger;

  Future<void> run(String yaml) async {
    await const AndroidIconsProcessor().apply(
      FlavorizrContext(
        config: FlavorizrConfig.parse(yaml),
        root: root,
        projectRoot: projectRoot,
        logger: logger,
      ),
    );
  }

  Uint8List output(String path) => File(
    p.join(root.path, 'android/app/src/dev/res', path),
  ).readAsBytesSync();

  img.Image decoded(String path) => img.decodePng(output(path))!;

  void writeProject(String path, List<int> bytes) =>
      File(p.join(projectRoot.path, path))
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes);

  setUp(() {
    final temp = Directory.systemTemp.createTempSync('flavorizr_badge_');
    addTearDown(() => temp.deleteSync(recursive: true));

    root = Directory(p.join(temp.path, 'shadow'))..createSync();
    projectRoot = Directory(p.join(temp.path, 'project'))..createSync();
    logger = _RecordingLogger();

    writeProject('assets/dev.png', gradientPng(512, 512));
    writeProject('assets/fg.png', gradientPng(216, 216));
    writeProject('assets/bg.png', gradientPng(108, 108));
    writeProject('assets/mono.png', gradientPng(108, 108));
  });

  /// The icons of a flavor with no badge: what badging must leave alone.
  Future<Map<String, Uint8List>> baseline(String yaml) async {
    await run(yaml);

    final files = {
      for (final folder in _legacyFolders)
        '$folder/ic_launcher.png': output('$folder/ic_launcher.png'),
    };

    Directory(p.join(root.path, 'android')).deleteSync(recursive: true);

    return files;
  }

  group('AndroidIconsProcessor with a badge', () {
    test('draws the band on every legacy mipmap, at its size', () async {
      final plain = await baseline(_config());

      await run(_config(flavorBadge: '    badge: { label: DEV }\n'));

      for (final folder in _legacyFolders) {
        final path = '$folder/ic_launcher.png';
        final before = img.decodePng(plain[path]!)!;
        final after = decoded(path);
        final band = badgeBand(after.width, BadgeArea.full);

        expect([after.width, after.height], [before.width, before.height]);

        for (var y = 0; y < band.top; y++) {
          for (var x = 0; x < after.width; x++) {
            final a = after.getPixel(x, y);
            final b = before.getPixel(x, y);

            expect([a.r, a.g, a.b, a.a], [b.r, b.g, b.b, b.a]);
          }
        }

        final corner = after.getPixel(0, after.height - 1);
        final color = defaultBadgeColor('dev');

        expect(
          [corner.r, corner.g, corner.b],
          [color.red, color.green, color.blue],
          reason: folder,
        );
      }
    });

    test(
      'is the one of the root `badge`, and a flavor says otherwise',
      () async {
        final plain = await baseline(_config());

        await run(_config(rootBadge: 'badge: true\n'));
        final badged = output('mipmap-xxxhdpi/ic_launcher.png');

        expect(badged, isNot(plain['mipmap-xxxhdpi/ic_launcher.png']));

        await run(
          _config(
            rootBadge: 'badge: true\n',
            flavorBadge: '    badge: false\n',
          ),
        );

        expect(
          output('mipmap-xxxhdpi/ic_launcher.png'),
          plain['mipmap-xxxhdpi/ic_launcher.png'],
        );
      },
    );

    test('regenerates when the badge changes, and restores the icons when it '
        'is off', () async {
      final plain = await baseline(_config());

      await run(_config(flavorBadge: '    badge: { label: DEV }\n'));
      final dev = output('mipmap-hdpi/ic_launcher.png');

      await run(_config(flavorBadge: '    badge: { label: QA }\n'));
      final qa = output('mipmap-hdpi/ic_launcher.png');

      await run(
        _config(flavorBadge: '    badge: { label: DEV, color: "#1E88E5" }\n'),
      );
      final blue = output('mipmap-hdpi/ic_launcher.png');

      // Lists are compared by content, not by identity.
      expect(dev, isNot(equals(qa)), reason: 'the label changed');
      expect(dev, isNot(equals(blue)), reason: 'the colour changed');
      expect(qa, isNot(equals(blue)));

      await run(_config());

      for (final folder in _legacyFolders) {
        expect(
          output('$folder/ic_launcher.png'),
          plain['$folder/ic_launcher.png'],
          reason: folder,
        );
      }
    });

    test('gives flavors that share a source icon the badge of each one, from '
        'a single run', () async {
      Uint8List of(String flavor, String path) => File(
        p.join(root.path, 'android/app/src/$flavor/res', path),
      ).readAsBytesSync();

      String flavor(String name, String badge) =>
          '''
  $name:
    app:
      name: "App"
    badge: $badge
    android:
      applicationId: "com.example.$name"
      icon: "assets/dev.png"
''';

      await run(
        'flavors:\n'
        '${flavor('dev', '{ label: DEV, color: "#E53935" }')}'
        '${flavor('qa', '{ label: QA, color: "#1E88E5" }')}'
        '${flavor('same', '{ label: DEV, color: "#E53935" }')}'
        '${flavor('plain', 'false')}',
      );

      for (final path in [
        'mipmap-mdpi/ic_launcher.png',
        'mipmap-xxxhdpi/ic_launcher.png',
      ]) {
        final dev = of('dev', path);
        final qa = of('qa', path);
        final plain = of('plain', path);

        expect(dev, isNot(equals(qa)), reason: 'label and colour: $path');
        expect(dev, isNot(equals(plain)), reason: 'badged or not: $path');
        expect(qa, isNot(equals(plain)), reason: 'badged or not: $path');
        // The same badge on the same source is the same icon.
        expect(of('same', path), dev, reason: path);
      }
    });

    test('is deterministic', () async {
      const yaml = 'badge: true\n';

      await run(_config(rootBadge: yaml));
      final first = output('mipmap-xhdpi/ic_launcher.png');

      await run(_config(rootBadge: yaml));

      expect(output('mipmap-xhdpi/ic_launcher.png'), first);
    });

    test('draws on the foreground of an adaptive icon, inside the safe zone, '
        'and on no other layer', () async {
      final plain = <String, Uint8List>{};

      await run(_config(flavorIcon: '', adaptive: _adaptive));
      for (final folder in _adaptiveFolders) {
        for (final layer in ['foreground', 'background', 'monochrome']) {
          plain['$folder/$layer'] = output('$folder/ic_launcher_$layer.png');
        }
      }
      final xml = output('mipmap-anydpi-v26/ic_launcher.xml');

      await run(
        _config(
          flavorBadge: '    badge: { label: STAGING }\n',
          flavorIcon: '',
          adaptive: _adaptive,
        ),
      );

      for (final folder in _adaptiveFolders) {
        expect(
          output('$folder/ic_launcher_background.png'),
          plain['$folder/background'],
        );
        expect(
          output('$folder/ic_launcher_monochrome.png'),
          plain['$folder/monochrome'],
        );

        final before = img.decodePng(plain['$folder/foreground']!)!;
        final after = decoded('$folder/ic_launcher_foreground.png');
        final size = after.width;
        final radius = size * 66 / 108 / 2;
        var changed = 0;

        for (var y = 0; y < size; y++) {
          for (var x = 0; x < size; x++) {
            final a = after.getPixel(x, y);
            final b = before.getPixel(x, y);

            if (a.r != b.r || a.g != b.g || a.b != b.b || a.a != b.a) {
              changed++;

              final dx = x + 0.5 - size / 2;
              final dy = y + 0.5 - size / 2;

              expect(
                math.sqrt(dx * dx + dy * dy),
                lessThanOrEqualTo(radius),
                reason: '$folder $x,$y',
              );
            }
          }
        }

        expect(changed, greaterThan(0), reason: folder);
      }

      expect(output('mipmap-anydpi-v26/ic_launcher.xml'), xml);
    });

    test(
      'takes the source of a flavor with no icon from the root `icon`',
      () async {
        writeProject('assets/root.png', gradientPng(600, 600));

        await run(
          _config(
            rootBadge: 'badge: true\nicon: assets/root.png\n',
            flavorIcon: '',
          ),
        );

        final icon = decoded('mipmap-xxxhdpi/ic_launcher.png');

        expect(icon.width, 192);
      },
    );

    test('fails with a hint when no icon is large enough', () async {
      writeProject('assets/dev.png', gradientPng(256, 256));

      await expectLater(
        run(_config(rootBadge: 'badge: true\n')),
        throwsA(isA<BadgeSourceIconException>()),
      );
    });

    test('is skipped, with a warning, when `main` has an adaptive icon that '
        'would shadow the legacy mipmaps', () async {
      writeProject(
        'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml',
        '<adaptive-icon/>'.codeUnits,
      );
      final plain = await baseline(_config());

      await run(_config(flavorBadge: '    badge: { label: DEV }\n'));

      for (final folder in _legacyFolders) {
        expect(
          output('$folder/ic_launcher.png'),
          plain['$folder/ic_launcher.png'],
          reason: folder,
        );
      }
      expect(logger.warnings, hasLength(1));
      expect(
        logger.warnings.single,
        allOf(
          contains('dev'),
          contains('badge'),
          contains('mipmap-anydpi-v26/ic_launcher.xml'),
          contains('adaptiveIcon'),
        ),
      );
    });

    test('is skipped, with a warning, for a vector adaptive foreground, and '
        'nothing is written for the flavor', () async {
      writeProject('assets/fg.xml', '<vector/>'.codeUnits);

      await run(
        _config(
          flavorBadge: '    badge: { label: DEV }\n',
          flavorIcon: '',
          adaptive: _adaptive.replaceFirst('fg.png', 'fg.xml'),
        ),
      );

      expect(Directory(p.join(root.path, 'android')).existsSync(), isFalse);
      expect(logger.warnings, hasLength(1));
      expect(
        logger.warnings.single,
        allOf(contains('dev'), contains('vector'), contains('assets/fg.xml')),
      );
      // Without the badge a vector foreground still is not decodable, so
      // turning the badge off is no way out of the warning.
      expect(logger.warnings.single, isNot(contains('badge: false')));
    });

    test('is not skipped by the adaptive icon of `main` when the flavor has an '
        'adaptive icon of its own', () async {
      writeProject(
        'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml',
        '<adaptive-icon/>'.codeUnits,
      );

      await run(
        _config(
          flavorBadge: '    badge: { label: DEV }\n',
          flavorIcon: '',
          adaptive: _adaptive,
        ),
      );

      expect(logger.warnings, isEmpty);
    });
  });
}
