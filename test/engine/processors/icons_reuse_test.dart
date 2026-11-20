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

import 'package:flutter_flavorizr/src/badge/badge_renderer.dart';
import 'package:flutter_flavorizr/src/badge/resolved_badge.dart';
import 'package:flutter_flavorizr/src/badge/badge_color.dart';
import 'package:flutter_flavorizr/src/engine/artifact.dart';
import 'package:flutter_flavorizr/src/engine/flavorizr_context.dart';
import 'package:flutter_flavorizr/src/engine/flavorizr_processor.dart';
import 'package:flutter_flavorizr/src/engine/processors/android/android_icons_processor.dart';
import 'package:flutter_flavorizr/src/engine/processors/darwin/darwin_icons_processors.dart';
import 'package:flutter_flavorizr/src/engine/processors/icon_inputs.dart';
import 'package:flutter_flavorizr/src/engine/processors/windows/windows_icons_processor.dart';
import 'package:flutter_flavorizr/src/engine/recorded_output.dart';
import 'package:flutter_flavorizr/src/engine/shadow/file_digest.dart';
import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../../test_utils.dart';
import 'android/android_icon_source_test.dart' show gradientPng;

/// What the processors of icons have in common: a run that finds an icon as the
/// lock recorded it, from the same inputs, leaves it alone.
class _Case {
  final String name;
  final FlavorizrProcessor processor;

  /// The configuration of a flavor `apple` with an icon, and a [badge] if any.
  final String Function(String icon, {bool badge}) config;

  /// The icon files the processor makes for `apple`, a few of them at least.
  final String icon;

  const _Case(this.name, this.processor, this.config, this.icon);
}

String _yaml(String platform, String body, String icon, bool badge) =>
    '''
flavors:
  apple:
    app:
      name: apple
      icon: $icon
${badge ? '    badge: { label: DEV, color: "#E53935" }\n' : ''}    $platform:
$body''';

final _cases = [
  _Case(
    'android:icons',
    const AndroidIconsProcessor(),
    (icon, {badge = false}) => _yaml(
      'android',
      '      applicationId: com.example.apple\n',
      icon,
      badge,
    ),
    'android/app/src/apple/res/mipmap-xhdpi/ic_launcher.png',
  ),
  _Case(
    'ios:icons',
    const IosIconsProcessor(),
    (icon, {badge = false}) =>
        _yaml('ios', '      bundleId: com.example.apple\n', icon, badge),
    'ios/Runner/Assets.xcassets/AppIcon-apple.appiconset/'
        'Icon-App-60x60@3x.png',
  ),
  _Case(
    'macos:icons',
    const MacosIconsProcessor(),
    (icon, {badge = false}) =>
        _yaml('macos', '      bundleId: com.example.apple\n', icon, badge),
    'macos/Runner/Assets.xcassets/AppIcon-apple.appiconset/app_icon_64.png',
  ),
  _Case(
    'windows:icons',
    const WindowsIconsProcessor(),
    (icon, {badge = false}) => _yaml(
      'windows',
      '',
      icon,
      badge,
    ).replaceFirst('windows:', 'windows: {}'),
    'windows/runner/resources/apple.ico',
  ),
];

void main() {
  late Directory shadow;
  late Directory project;

  File inShadow(String path) => File(p.join(shadow.path, path));

  void writeSource(String path, List<int> bytes) =>
      File(p.join(project.path, path))
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes);

  setUp(() {
    final temp = Directory.systemTemp.createTempSync('flavorizr_icons_reuse_');
    addTearDown(() => temp.deleteSync(recursive: true));

    shadow = Directory(p.join(temp.path, 'shadow'))..createSync();
    project = Directory(p.join(temp.path, 'project'))..createSync();
    writeSource('assets/apple.png', gradientPng(1024, 1024));
    writeSource('assets/banana.png', gradientPng(512, 512));
  });

  /// A run of [processor], as the next one after the one the lock [previous]
  /// recorded, on the same workspace, which holds what the last run wrote.
  Future<FlavorizrContext> run(
    FlavorizrProcessor processor,
    String yaml, {
    Map<String, RecordedOutput> previous = const {},
  }) async {
    final ctx = FlavorizrContext(
      config: FlavorizrConfig.parse(yaml),
      root: shadow,
      projectRoot: project,
      logger: TestUtils.quietLogger(),
      processorId: processor.id,
      previousOutputs: {processor.id: previous},
    );

    await processor.apply(ctx);

    return ctx;
  }

  /// What the lock would record about [ctx], as the engine does.
  Map<String, RecordedOutput> recorded(FlavorizrContext ctx) => {
    for (final artifact in ctx.tracked)
      if (artifact.inputs != null)
        artifact.path: RecordedOutput(
          hash: digestOf(inShadow(artifact.path).readAsBytesSync()),
          inputs: artifact.inputs!,
        ),
  };

  String? inputsOf(FlavorizrContext ctx, String path) =>
      ctx.tracked.firstWhere((artifact) => artifact.path == path).inputs;

  for (final testCase in _cases) {
    group(testCase.name, () {
      test('declares the inputs of every image it makes, and none for the '
          'files that are text', () async {
        final ctx = await run(
          testCase.processor,
          testCase.config('assets/apple.png'),
        );
        final images = ctx.tracked.where(
          (artifact) =>
              artifact.path.endsWith('.png') || artifact.path.endsWith('.ico'),
        );

        expect(images, isNotEmpty);
        expect(
          images.map((artifact) => artifact.inputs),
          everyElement(isNotNull),
        );
        expect(
          ctx.tracked.where((artifact) => artifact.path.endsWith('.json')),
          everyElement(isA<ManagedArtifact>()),
        );
        expect(
          ctx.tracked
              .where(
                (artifact) =>
                    artifact.path.endsWith('.json') ||
                    artifact.path.endsWith('.xml'),
              )
              .map((artifact) => artifact.inputs),
          everyElement(isNull),
        );
      });

      test('declares the same inputs on every run', () async {
        final first = await run(
          testCase.processor,
          testCase.config('assets/apple.png'),
        );
        final second = await run(
          testCase.processor,
          testCase.config('assets/apple.png'),
        );

        expect(second.tracked, first.tracked);
      });

      test('leaves an image as it is when the lock has its inputs and its '
          'hash, whatever another renderer would make', () async {
        final first = await run(
          testCase.processor,
          testCase.config('assets/apple.png'),
        );

        // Another machine made these bytes, and the lock says so.
        inShadow(testCase.icon).writeAsBytesSync([7, 7, 7]);

        final second = await run(
          testCase.processor,
          testCase.config('assets/apple.png'),
          previous: recorded(first),
        );

        expect(inShadow(testCase.icon).readAsBytesSync(), [7, 7, 7]);
        expect(second.tracked, first.tracked);
      });

      test('makes it again when the lock does not have the inputs', () async {
        final first = await run(
          testCase.processor,
          testCase.config('assets/apple.png'),
        );
        final icon = inShadow(testCase.icon).readAsBytesSync();

        inShadow(testCase.icon).writeAsBytesSync([7, 7, 7]);
        await run(
          testCase.processor,
          testCase.config('assets/apple.png'),
          previous: {
            for (final entry in recorded(first).entries)
              if (entry.key != testCase.icon) entry.key: entry.value,
          },
        );

        expect(inShadow(testCase.icon).readAsBytesSync(), icon);
      });

      test('makes it again, and finds the conflict, when it was edited '
          'since the lock', () async {
        final first = await run(
          testCase.processor,
          testCase.config('assets/apple.png'),
        );
        final lock = recorded(first);
        final icon = inShadow(testCase.icon).readAsBytesSync();

        inShadow(testCase.icon).writeAsBytesSync([1, 2, 3]);
        await run(
          testCase.processor,
          testCase.config('assets/apple.png'),
          previous: lock,
        );

        expect(inShadow(testCase.icon).readAsBytesSync(), icon);
      });

      test('makes it again when the source changes, and not before', () async {
        final first = await run(
          testCase.processor,
          testCase.config('assets/apple.png'),
        );
        final lock = recorded(first);

        writeSource('assets/apple.png', gradientPng(1000, 1024));
        inShadow(testCase.icon).writeAsBytesSync([7, 7, 7]);

        final second = await run(
          testCase.processor,
          testCase.config('assets/apple.png'),
          previous: lock,
        );

        expect(inShadow(testCase.icon).readAsBytesSync(), isNot([7, 7, 7]));
        expect(
          inputsOf(second, testCase.icon),
          isNot(inputsOf(first, testCase.icon)),
        );
      });

      test(
        'does not make it again for another path with the same image',
        () async {
          final first = await run(
            testCase.processor,
            testCase.config('assets/apple.png'),
          );

          writeSource(
            'assets/copy.png',
            File(p.join(project.path, 'assets/apple.png')).readAsBytesSync(),
          );
          inShadow(testCase.icon).writeAsBytesSync([7, 7, 7]);

          final second = await run(
            testCase.processor,
            testCase.config('assets/copy.png'),
            previous: recorded(first),
          );

          expect(inShadow(testCase.icon).readAsBytesSync(), [7, 7, 7]);
          expect(second.tracked, first.tracked);
        },
      );

      test('makes it again with a badge, and as it was without one', () async {
        final plain = await run(
          testCase.processor,
          testCase.config('assets/apple.png'),
        );
        final bytes = inShadow(testCase.icon).readAsBytesSync();
        final badged = await run(
          testCase.processor,
          testCase.config('assets/apple.png', badge: true),
          previous: recorded(plain),
        );

        expect(inShadow(testCase.icon).readAsBytesSync(), isNot(bytes));
        expect(
          inputsOf(badged, testCase.icon),
          isNot(inputsOf(plain, testCase.icon)),
        );

        final restored = await run(
          testCase.processor,
          testCase.config('assets/apple.png'),
          previous: recorded(badged),
        );

        expect(inShadow(testCase.icon).readAsBytesSync(), bytes);
        expect(
          inputsOf(restored, testCase.icon),
          inputsOf(plain, testCase.icon),
        );
      });

      test('fails when the source is gone, though the images are up to '
          'date', () async {
        final first = await run(
          testCase.processor,
          testCase.config('assets/apple.png'),
        );

        File(p.join(project.path, 'assets/apple.png')).deleteSync();

        await expectLater(
          run(
            testCase.processor,
            testCase.config('assets/apple.png'),
            previous: recorded(first),
          ),
          throwsA(isA<Exception>()),
        );
      });
    });
  }

  group('android:icons, adaptive icons', () {
    String config({bool badge = false}) =>
        '''
flavors:
  apple:
    app:
      name: apple
${badge ? '    badge: { label: DEV, color: "#E53935" }\n' : ''}    android:
      applicationId: com.example.apple
      adaptiveIcon:
        foreground: assets/apple.png
        background: assets/banana.png
''';
    const foreground =
        'android/app/src/apple/res/drawable-xxxhdpi/ic_launcher_foreground.png';
    const background =
        'android/app/src/apple/res/drawable-xxxhdpi/ic_launcher_background.png';

    test('a badge makes the foreground again, and only it', () async {
      const processor = AndroidIconsProcessor();
      final plain = await run(processor, config());
      final background0 = inShadow(background).readAsBytesSync();

      inShadow(background).writeAsBytesSync([7, 7, 7]);

      final badged = await run(
        processor,
        config(badge: true),
        previous: recorded(plain),
      );

      expect(inputsOf(badged, foreground), isNot(inputsOf(plain, foreground)));
      expect(inputsOf(badged, background), inputsOf(plain, background));
      // The background is up to date, so it is not made again.
      expect(inShadow(background).readAsBytesSync(), [7, 7, 7]);
      expect(background0, isNot([7, 7, 7]));
    });

    test('the XML of the icon is made every time, with no inputs', () async {
      final ctx = await run(const AndroidIconsProcessor(), config());

      expect(
        inputsOf(
          ctx,
          'android/app/src/apple/res/mipmap-anydpi-v26/ic_launcher.xml',
        ),
        isNull,
      );
    });
  });

  group('GeneratedIcons', () {
    List<int> solid(int red) => img.encodePng(
      img.Image(width: 8, height: 8)..clear(img.ColorRgb8(red, 0, 0)),
    );

    FlavorizrContext context() => FlavorizrContext(
      config: FlavorizrConfig.parse(
        'flavors:\n  apple:\n    app:\n      name: apple\n',
      ),
      root: shadow,
      projectRoot: project,
      logger: TestUtils.quietLogger(),
      processorId: 'android:icons',
    );

    test('hashes and renders the same snapshot of a source that changes in '
        'between, which is read once', () async {
      writeSource('assets/a.png', solid(10));

      final files = GeneratedIcons(context());
      final digest = await files.sourceDigest('assets/a.png');

      writeSource('assets/a.png', solid(200));

      final image = await files.loadSource('assets/a.png');
      final pixel = img.decodePng(image.renderPng(4, 4))!.getPixel(0, 0);

      expect(pixel.r, 10);
      expect(digest, digestOf(solid(10)));
      expect(await files.sourceDigest('./assets/a.png'), digest);
    });
  });

  group('iconInputs', () {
    const digest = 'sha256:aaa';
    final badge = ResolvedBadge(
      label: 'DEV',
      color: BadgeColor.parse('#E53935'),
    );

    String inputs({
      String kind = 'png',
      String source = digest,
      List<int> sizes = const [48, 48],
      ResolvedBadge? badge,
      BadgeArea area = BadgeArea.full,
    }) => iconInputs(
      kind: kind,
      sourceDigest: source,
      sizes: sizes,
      badge: badge,
      area: area,
    );

    test('is a digest, and the same for the same inputs', () {
      expect(inputs(), matches(RegExp(r'^sha256:[0-9a-f]{64}$')));
      expect(inputs(), inputs());
      expect(inputs(badge: badge), inputs(badge: badge));
    });

    test('is a known value, so that it is the same on every machine and '
        'version, until the rendering is meant to change', () {
      expect(iconRenderingVersion, 1);
      expect(
        inputs(sizes: [48, 48]),
        digestOf(
          '{"rendering":1,"kind":"png","source":"sha256:aaa",'
                  '"sizes":[48,48],"badge":null}'
              .codeUnits,
        ),
      );
    });

    test('changes with each thing the pixels depend on', () {
      final values = {
        inputs(),
        inputs(kind: 'ico'),
        inputs(source: 'sha256:bbb'),
        inputs(sizes: [96, 96]),
        inputs(badge: badge),
        inputs(
          badge: ResolvedBadge(label: 'QA', color: badge.color),
        ),
        inputs(
          badge: ResolvedBadge(
            label: 'DEV',
            color: BadgeColor.parse('#1E88E5'),
          ),
        ),
        inputs(badge: badge, area: BadgeArea.safeZone),
      };

      expect(values, hasLength(8));
    });

    test('does not depend on the area when there is no badge to draw', () {
      expect(inputs(area: BadgeArea.safeZone), inputs(area: BadgeArea.full));
    });
  });
}
