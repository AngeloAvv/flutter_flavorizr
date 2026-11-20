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
import 'dart:typed_data';

import 'package:flutter_flavorizr/src/engine/artifact.dart';
import 'package:flutter_flavorizr/src/engine/flavorizr_context.dart';
import 'package:flutter_flavorizr/src/engine/ownership.dart';
import 'package:flutter_flavorizr/src/engine/processors/darwin/darwin_icons_processors.dart';
import 'package:flutter_flavorizr/src/exception/file_not_found_exception.dart';
import 'package:flutter_flavorizr/src/exception/invalid_configuration_exception.dart';
import 'package:flutter_flavorizr/src/exception/malformed_resource_exception.dart';
import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../../../test_utils.dart';
import '../android/android_icon_source_test.dart' show gradientPng;

/// What differs between iOS and macOS.
class _Platform {
  final String name;
  final DarwinIconsProcessor processor;
  final String assets;

  /// A few of the files of a set, the smallest and the biggest among them.
  final List<String> files;

  /// The files of a set, `Contents.json` not counted.
  final int count;

  /// The entries of the `Contents.json`.
  final int entries;

  /// How the `Contents.json` starts.
  final String contentsStart;

  /// The side in pixels of the icon of a file, which its name says.
  final int Function(String file) sizeOf;

  const _Platform({
    required this.name,
    required this.processor,
    required this.assets,
    required this.files,
    required this.count,
    required this.entries,
    required this.contentsStart,
    required this.sizeOf,
  });

  String set(String flavor) => '$assets/AppIcon-$flavor.appiconset';
}

int _iosSize(String file) {
  final match = RegExp(r'-([\d.]+)x[\d.]+@(\d)x').firstMatch(file)!;

  return (double.parse(match.group(1)!) * int.parse(match.group(2)!)).round();
}

final _ios = _Platform(
  name: 'ios',
  processor: const IosIconsProcessor(),
  assets: 'ios/Runner/Assets.xcassets',
  files: const [
    'Icon-App-20x20@2x.png',
    'Icon-App-83.5x83.5@2x.png',
    'Icon-App-1024x1024@1x.png',
  ],
  // iPhone and iPad share the files of the sizes they have in common.
  count: 15,
  entries: 19,
  contentsStart:
      '{"images":[{"size":"20x20","idiom":"iphone","scale":"2x",'
      '"filename":"Icon-App-20x20@2x.png"},',
  sizeOf: _iosSize,
);

final _macos = _Platform(
  name: 'macos',
  processor: const MacosIconsProcessor(),
  assets: 'macos/Runner/Assets.xcassets',
  files: const ['app_icon_16.png', 'app_icon_32.png', 'app_icon_1024.png'],
  // The 2x of a size and the 1x of the next one are the same file.
  count: 7,
  entries: 10,
  contentsStart:
      '{"images":[{"size":"16x16","idiom":"mac","scale":"1x",'
      '"filename":"app_icon_16.png"},',
  sizeOf: (file) => int.parse(RegExp(r'_(\d+)\.').firstMatch(file)!.group(1)!),
);

String _config(
  _Platform platform, {
  String flavor = '      icon: "assets/dev.png"\n',
  String badge = '',
}) =>
    '''
flavors:
  dev:
    app:
      name: "App"
$flavor$badge    ${platform.name}:
      bundleId: "com.example.dev"
''';

const _band = [0xE5, 0x39, 0x35];
const _badged = '    badge: { label: DEV, color: "#E53935" }\n';

void main() {
  late Directory root;
  late Directory projectRoot;

  void writeProject(String path, List<int> bytes) =>
      File(p.join(projectRoot.path, path))
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes);

  setUp(() {
    final temp = Directory.systemTemp.createTempSync('flavorizr_darwin_icons_');
    addTearDown(() => temp.deleteSync(recursive: true));

    root = Directory(p.join(temp.path, 'shadow'))..createSync();
    projectRoot = Directory(p.join(temp.path, 'project'))..createSync();
    writeProject('assets/dev.png', gradientPng(1024, 1024));
  });

  for (final platform in [_ios, _macos]) {
    group('${platform.name}:icons', () {
      File out(String path) => File(p.join(root.path, path));

      Uint8List icon(String flavor, String file) =>
          out('${platform.set(flavor)}/$file').readAsBytesSync();

      bool wrote() =>
          Directory(p.join(root.path, platform.assets)).existsSync();

      Future<List<Artifact>> run(String yaml) async {
        final ctx = FlavorizrContext(
          config: FlavorizrConfig.parse(yaml),
          root: root,
          projectRoot: projectRoot,
          logger: TestUtils.quietLogger(),
        );

        await platform.processor.apply(ctx);

        return ctx.tracked;
      }

      void reset() {
        root.deleteSync(recursive: true);
        root.createSync();
      }

      List<int> resized(Uint8List source, int size) => img.encodePng(
        img.copyResize(
          img.decodePng(source)!,
          width: size,
          height: size,
          interpolation: img.Interpolation.average,
        ),
      );

      test('makes the appiconset of a flavor from its icon', () async {
        final tracked = await run(_config(platform));
        final set = platform.set('dev');

        expect(out('$set/Contents.json').existsSync(), isTrue);
        for (final file in platform.files) {
          expect(out('$set/$file').existsSync(), isTrue, reason: file);
        }
        expect(tracked, hasLength(platform.count + 1));
        expect(
          tracked.map((artifact) => artifact.ownership),
          everyElement(Ownership.managed),
        );
        expect(
          tracked.map((artifact) => artifact.path),
          contains('$set/Contents.json'),
        );
      });

      test(
        'resizes the icon the way 2.x did, at the size of each file',
        () async {
          await run(_config(platform));
          final source = gradientPng(1024, 1024);

          for (final file in platform.files) {
            expect(
              icon('dev', file),
              resized(source, platform.sizeOf(file)),
              reason: file,
            );
          }
        },
      );

      test('writes the Contents.json 2.x wrote, byte for byte', () async {
        await run(_config(platform));

        final contents = utf8.decode(icon('dev', 'Contents.json'));

        expect(contents, startsWith(platform.contentsStart));
        expect(contents, endsWith('],"info":{"version":1,"author":"xcode"}}'));
        expect(jsonDecode(contents)['images'], hasLength(platform.entries));
      });

      test('prefers the icon of the platform to the one of the app', () async {
        writeProject('assets/other.png', gradientPng(600, 600));

        await run('''
flavors:
  dev:
    app:
      name: "App"
      icon: "assets/dev.png"
    ${platform.name}:
      bundleId: "com.example.dev"
      icon: "assets/other.png"
''');

        final file = platform.files.first;

        expect(
          icon('dev', file),
          resized(gradientPng(600, 600), platform.sizeOf(file)),
        );
      });

      test('makes nothing for a flavor with no icon and no badge', () async {
        final tracked = await run(_config(platform, flavor: ''));

        expect(tracked, isEmpty);
        expect(wrote(), isFalse);
      });

      test('makes nothing for the flavors of the other platform', () async {
        final tracked = await run(_config(platform == _ios ? _macos : _ios));

        expect(tracked, isEmpty);
        expect(wrote(), isFalse);
      });

      test('makes a set for each flavor, from its own icon', () async {
        writeProject('assets/qa.png', gradientPng(300, 300));

        final tracked = await run('''
flavors:
  dev:
    app:
      name: "Dev"
      icon: "assets/dev.png"
    ${platform.name}:
      bundleId: "com.example.dev"
  qa:
    app:
      name: "QA"
      icon: "assets/qa.png"
    ${platform.name}:
      bundleId: "com.example.qa"
  prod:
    app:
      name: "Prod"
    ${platform.name}:
      bundleId: "com.example.prod"
''');

        expect(tracked, hasLength(2 * (platform.count + 1)));
        expect(
          tracked.map((artifact) => artifact.path),
          everyElement(anyOf(contains('AppIcon-dev'), contains('AppIcon-qa'))),
        );
        expect(
          icon('dev', platform.files.first),
          isNot(icon('qa', platform.files.first)),
        );
      });

      test('writes nothing when the icon of a flavor is missing', () async {
        await expectLater(
          run(_config(platform, flavor: '      icon: "assets/gone.png"\n')),
          throwsA(isA<FileNotFoundException>()),
        );
        expect(wrote(), isFalse);
      });

      test('writes nothing when a later flavor has a broken icon', () async {
        writeProject('assets/broken.png', [1, 2, 3]);

        await expectLater(
          run('''
flavors:
  dev:
    app:
      name: "Dev"
      icon: "assets/dev.png"
    ${platform.name}:
      bundleId: "com.example.dev"
  qa:
    app:
      name: "QA"
      icon: "assets/broken.png"
    ${platform.name}:
      bundleId: "com.example.qa"
'''),
          throwsA(isA<MalformedResourceException>()),
        );
        expect(wrote(), isFalse);
      });

      test('refuses an icon that leads out of the project', () async {
        File(
          p.join(projectRoot.parent.path, 'outside.png'),
        ).writeAsBytesSync(gradientPng(64, 64));

        await expectLater(
          run(_config(platform, flavor: '      icon: "../outside.png"\n')),
          throwsArgumentError,
        );
        expect(wrote(), isFalse);
      });

      test('refuses the name of a flavor that is no file name', () async {
        await expectLater(
          run('''
flavors:
  "a b":
    app:
      name: "Dev"
      icon: "assets/dev.png"
    ${platform.name}:
      bundleId: "com.example.dev"
'''),
          throwsArgumentError,
        );
        expect(wrote(), isFalse);
      });

      test('runs after the dummy assets and works on the asset catalog', () {
        expect(platform.processor.id, '${platform.name}:icons');
        expect(platform.processor.after, {'${platform.name}:dummyAssets'});
        expect(platform.processor.paths, {platform.assets});
      });

      group('with a badge', () {
        img.Image decoded(String file) => img.decodePng(icon('dev', file))!;

        List<num> corner(String file) {
          final image = decoded(file);
          final pixel = image.getPixel(0, image.height - 1);

          return [pixel.r, pixel.g, pixel.b];
        }

        test('draws the band on every icon, at its size', () async {
          await run(_config(platform, badge: _badged));

          for (final file in platform.files) {
            expect(corner(file), _band, reason: file);
            expect(decoded(file).width, platform.sizeOf(file), reason: file);
          }
        });

        test(
          'leaves the icons of a flavor with no badge as they are',
          () async {
            await run(_config(platform));

            for (final file in platform.files) {
              expect(corner(file), isNot(_band), reason: file);
            }
          },
        );

        test('makes the icons of a flavor with a badge and no icon, from the '
            'icon of the root', () async {
          final tracked = await run('''
icon: "assets/dev.png"
flavors:
  dev:
    app:
      name: "App"
$_badged    ${platform.name}:
      bundleId: "com.example.dev"
''');

          expect(tracked, hasLength(platform.count + 1));
          expect(corner(platform.files.first), _band);
        });

        test('draws it on the icon of the root when the one of the flavor is '
            'too small', () async {
          writeProject('assets/small.png', gradientPng(300, 300));

          Future<Uint8List> last(String flavorIcon) async {
            reset();

            await run('''
icon: "assets/dev.png"
flavors:
  dev:
    app:
      name: "App"
$flavorIcon$_badged    ${platform.name}:
      bundleId: "com.example.dev"
''');

            return icon('dev', platform.files.last);
          }

          expect(
            await last('      icon: "assets/small.png"\n'),
            await last(''),
          );
        });

        test('fails with a hint when there is no icon to draw it on', () async {
          await expectLater(
            run('''
flavors:
  dev:
    app:
      name: "App"
$_badged    ${platform.name}:
      bundleId: "com.example.dev"
'''),
            throwsA(
              isA<InvalidConfigurationException>().having(
                (error) => error.message,
                'message',
                allOf(contains('`dev`'), contains('`icon`')),
              ),
            ),
          );
          expect(wrote(), isFalse);
        });

        test('is the one of the root, and a flavor says otherwise', () async {
          await run('''
badge: true
flavors:
  dev:
    app:
      name: "App"
      icon: "assets/dev.png"
    badge: false
    ${platform.name}:
      bundleId: "com.example.dev"
''');

          for (final file in platform.files) {
            expect(corner(file), isNot(_band), reason: file);
          }
        });

        test('is deterministic', () async {
          await run(_config(platform, badge: _badged));
          final first = icon('dev', platform.files.first);

          await run(_config(platform, badge: _badged));

          expect(icon('dev', platform.files.first), first);
        });
      });
    });
  }
}
