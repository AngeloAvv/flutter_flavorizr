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

import 'package:dart_xcodeproj/dart_xcodeproj.dart';
import 'package:flutter_flavorizr/src/engine/lock/lock_store.dart';
import 'package:flutter_flavorizr/src/engine/processors/darwin/launch_screen_sources.dart';
import 'package:flutter_flavorizr/src/entrypoint/exit_codes.dart';
import 'package:flutter_flavorizr/src/entrypoint/processor_registry.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../../../entrypoint/cli_fixture.dart';
import '../../darwin/pbxproj_integrity.dart';
import '../../darwin/pristine_project.dart';

const _pbxproj = 'ios/Runner.xcodeproj/project.pbxproj';
const _runner = 'ios/Runner';
const _assets = '$_runner/Assets.xcassets';

const _icons = {
  'apple': '      icon: assets/apple.png\n',
  'banana': '      icon: assets/banana.png\n',
};

String _config({
  String root = '',
  Map<String, String> flavors = const {'apple': '', 'banana': ''},
}) =>
    '''
$root
flavors:
${[for (final MapEntry(:key, :value) in flavors.entries) '''
  $key:
    app:
      name: "$key"
    ios:
      bundleId: "com.example.$key"
$value'''].join()}''';

/// A square icon of one colour.
List<int> _icon(img.Color color, {int size = 1024}) =>
    img.encodePng(img.Image(width: size, height: size)..clear(color));

img.Image _decode(List<int> bytes) => img.decodePng(Uint8List.fromList(bytes))!;

String _storyboard(String flavor) =>
    '$_runner/${flavor}LaunchScreen.storyboard';
String _imageset(String flavor) => '$_assets/${flavor}LaunchImage.imageset';

void main() {
  late CliFixture project;
  late Directory temp;
  late String pristine;

  Future<int> apply() => project.run(['apply', '--yes', 'ios:launchScreen']);

  List<int> bytes(String path) => File(project.abs(path)).readAsBytesSync();

  img.Pixel pixel(String path, int x, int y) =>
      _decode(bytes(path)).getPixel(x, y);

  /// Every file of the project, by path, with its bytes.
  Map<String, List<int>> snapshot() => {
    for (final file in project.root.listSync(recursive: true).whereType<File>())
      p.relative(file.path, from: project.root.path): file.readAsBytesSync(),
  };

  Future<XcodeProject> open() =>
      XcodeProject.open(project.abs('ios/Runner.xcodeproj'));

  void writeIcon(String path, img.Color color) {
    final file = File(project.abs(path))..parent.createSync(recursive: true);

    file.writeAsBytesSync(_icon(color));
  }

  setUpAll(() {
    temp = Directory.systemTemp.createTempSync('flavorizr_launch_screen_');
  });
  tearDownAll(() => temp.deleteSync(recursive: true));

  setUp(() async {
    pristine = await pristineIosPbxproj(temp);
    project = CliFixture(android: false);
    project.write('flavorizr.yaml', _config());
    project.write(_pbxproj, pristine);
  });
  tearDown(() => project.dispose());

  group('ios:launchScreen', () {
    test('is a processor of the engine, in the recipe of iOS', () {
      final registry = ProcessorRegistry.standard();

      expect(registry.engineProcessors, contains('ios:launchScreen'));
    });

    test('makes nothing for a configuration without a launch screen, and '
        'leaves the project as it is', () async {
      final before = snapshot();

      final code = await apply();

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(
        snapshot().keys.where((path) => !path.contains('flavorizr.lock')),
        before.keys.toSet(),
      );
      expect(project.read(_pbxproj), pristine);
    });

    group('with a launch screen', () {
      setUp(() {
        writeIcon('assets/apple.png', img.ColorRgb8(200, 30, 30));
        writeIcon('assets/banana.png', img.ColorRgb8(30, 30, 200));
        project.write(
          'flavorizr.yaml',
          _config(root: 'launchScreen: true', flavors: _icons),
        );
      });

      test('writes the storyboard and the imageset of every flavor', () async {
        final code = await apply();

        expect(code, ExitCodes.ok, reason: project.logger.output);

        for (final flavor in ['apple', 'banana']) {
          expect(
            project.read(_storyboard(flavor)),
            launchScreenStoryboard(flavor),
          );
          expect(
            project.read('${_imageset(flavor)}/Contents.json'),
            launchImageContents,
          );
          for (final MapEntry(key: name, value: size)
              in launchImageSizes.entries) {
            final image = _decode(bytes('${_imageset(flavor)}/$name'));

            expect(image.width, size, reason: '$flavor $name');
            expect(image.height, size, reason: '$flavor $name');
          }
        }
      });

      test('makes the image from the icon of the flavor', () async {
        await apply();

        final apple = pixel(
          '${_imageset('apple')}/LaunchImage@2x.png',
          128,
          128,
        );
        final banana = pixel(
          '${_imageset('banana')}/LaunchImage@2x.png',
          128,
          128,
        );

        expect([apple.r, apple.b], [200, 30]);
        expect([banana.r, banana.b], [30, 200]);
      });

      test('draws the badge on it when the flavor has one', () async {
        project.write(
          'flavorizr.yaml',
          _config(
            root: 'launchScreen: true',
            flavors: {
              'apple':
                  '${_icons['apple']}'
                  '    badge: { label: DEV, color: "#00FF00" }\n',
              'banana': _icons['banana']!,
            },
          ),
        );

        await apply();

        final middle = pixel(
          '${_imageset('apple')}/LaunchImage@3x.png',
          192,
          192,
        );
        final band = pixel('${_imageset('apple')}/LaunchImage@3x.png', 2, 383);

        // The middle is the icon, the bottom row is the band.
        expect(middle.r, 200);
        expect([band.r, band.g, band.b], [0, 255, 0]);
        expect(
          pixel('${_imageset('banana')}/LaunchImage@3x.png', 2, 383).b,
          200,
        );
      });

      test('falls back to the icon of the root, then the AppIcon of the '
          'project', () async {
        writeIcon('assets/root.png', img.ColorRgb8(10, 200, 10));
        project.write(
          'flavorizr.yaml',
          _config(root: 'launchScreen: true\nicon: assets/root.png'),
        );

        await apply();

        expect(pixel('${_imageset('apple')}/LaunchImage.png', 64, 64).g, 200);

        // The AppIcon of the project, when nothing else says.
        project.write('flavorizr.yaml', _config(root: 'launchScreen: true'));
        File(project.abs('assets/root.png')).deleteSync();
        project.write(
          '$_assets/AppIcon.appiconset/Contents.json',
          '{"images":[{"size":"1024x1024","idiom":"ios-marketing",'
              '"filename":"Icon-1024.png","scale":"1x"}]}',
        );
        writeIcon(
          '$_assets/AppIcon.appiconset/Icon-1024.png',
          img.ColorRgb8(9, 9, 99),
        );

        await apply();

        expect(pixel('${_imageset('banana')}/LaunchImage.png', 64, 64).b, 99);
      });

      test('fails, before it writes anything, for a flavor with no icon to '
          'make it from', () async {
        project.write('flavorizr.yaml', _config(root: 'launchScreen: true'));
        final before = snapshot();

        final code = await apply();

        expect(code, ExitCodes.software, reason: project.logger.output);
        expect(project.logger.output, contains('launch screen'));
        expect(
          snapshot().keys.where((path) => !path.contains('flavorizr.lock')),
          before.keys.toSet(),
        );
      });

      test('makes it only for the flavors that have one', () async {
        project.write(
          'flavorizr.yaml',
          _config(
            flavors: {
              'apple': '${_icons['apple']}    launchScreen: true\n',
              'banana': _icons['banana']!,
            },
          ),
        );

        await apply();

        expect(project.exists(_storyboard('apple')), isTrue);
        expect(project.exists(_storyboard('banana')), isFalse);
        expect(project.exists(_imageset('banana')), isFalse);
      });

      test('puts the storyboards in the project, as resources of the app '
          'and nothing else', () async {
        await apply();

        final xcodeproj = await open();
        final resources = xcodeproj
            .nativeTargets
            .first
            .resourcesBuildPhase
            .files
            .map((file) => file.fileRef)
            .toList();

        for (final flavor in ['apple', 'banana']) {
          final reference = xcodeproj.files.singleWhere(
            (file) => file.path == 'Runner/${flavor}LaunchScreen.storyboard',
          );

          expect(reference.lastKnownFileType, 'file.storyboard');
          expect(resources, contains(reference));
        }
        expect(danglingUuids(project.read(_pbxproj)), isEmpty);
      });

      test('records what it made in the lock', () async {
        await apply();

        final lock = (await LockStore(
          project.root,
          runningVersion: '3.0.0',
        ).read())!;
        final processor = lock.processors['ios:launchScreen']!;

        expect(
          processor.files.keys,
          containsAll([
            _storyboard('apple'),
            '${_imageset('apple')}/Contents.json',
            '${_imageset('apple')}/LaunchImage@3x.png',
            _storyboard('banana'),
          ]),
        );
        // A reference and a build file for each storyboard.
        expect(processor.objects[_pbxproj], hasLength(4));
      });

      test('changes nothing on a second run', () async {
        await apply();
        final before = snapshot();

        final code = await apply();

        expect(code, ExitCodes.ok, reason: project.logger.output);
        expect(snapshot(), before);
      });

      test('writes nothing in a dry run', () async {
        final before = snapshot();

        final code = await project.run(['plan', 'ios:launchScreen']);

        expect(code, ExitCodes.ok, reason: project.logger.output);
        expect(snapshot(), before);
      });

      test('writes the image again when the icon changes', () async {
        await apply();
        final before = bytes('${_imageset('apple')}/LaunchImage.png');

        writeIcon('assets/apple.png', img.ColorRgb8(1, 2, 3));
        await apply();

        expect(bytes('${_imageset('apple')}/LaunchImage.png'), isNot(before));
      });

      test('is a conflict when the storyboard was edited by hand', () async {
        await apply();
        project.write(
          _storyboard('apple'),
          '${project.read(_storyboard('apple'))}<!-- mine -->\n',
        );
        final before = snapshot();

        final code = await apply();

        expect(code, ExitCodes.attention, reason: project.logger.output);
        expect(snapshot(), before);
      });

      test('removes what it made when the option goes off, and the project '
          'is as it was', () async {
        final untouched = snapshot();

        await apply();
        project.write('flavorizr.yaml', _config(flavors: _icons));

        final code = await apply();

        expect(code, ExitCodes.ok, reason: project.logger.output);
        for (final flavor in ['apple', 'banana']) {
          expect(project.exists(_storyboard(flavor)), isFalse);
          expect(project.exists(_imageset(flavor)), isFalse);
        }
        expect(project.read(_pbxproj), pristine);
        expect(danglingUuids(project.read(_pbxproj)), isEmpty);
        expect(
          snapshot().keys.where((path) => !path.contains('flavorizr.lock')),
          untouched.keys,
        );
      });

      test('removes only the flavor that turns it off', () async {
        await apply();
        project.write(
          'flavorizr.yaml',
          _config(
            root: 'launchScreen: true',
            flavors: {
              'apple': _icons['apple']!,
              'banana': '${_icons['banana']}    launchScreen: false\n',
            },
          ),
        );

        await apply();

        expect(project.exists(_storyboard('apple')), isTrue);
        expect(project.exists(_storyboard('banana')), isFalse);
        expect(project.exists(_imageset('banana')), isFalse);
        expect(project.read(_pbxproj), contains('appleLaunchScreen'));
        expect(project.read(_pbxproj), isNot(contains('bananaLaunchScreen')));
      });
    });

    group('with what 2.x made', () {
      const twoX = 'THE STORYBOARD OF 2.x';

      setUp(() {
        writeIcon('assets/apple.png', img.ColorRgb8(200, 30, 30));
        project.write(_storyboard('apple'), twoX);
        project.write('${_imageset('apple')}/Contents.json', '2.x contents');
        project.write('${_imageset('apple')}/LaunchImage.png', '2.x image');
        project.write(
          'flavorizr.yaml',
          _config(
            root: 'launchScreen: true',
            flavors: {'apple': _icons['apple']!},
          ),
        );
      });

      test('is the user\'s: it is never overwritten', () async {
        final code = await apply();

        expect(code, ExitCodes.ok, reason: project.logger.output);
        expect(project.read(_storyboard('apple')), twoX);
        expect(
          project.read('${_imageset('apple')}/Contents.json'),
          '2.x contents',
        );
        expect(
          project.read('${_imageset('apple')}/LaunchImage.png'),
          '2.x image',
        );
        expect(
          project.exists('${_imageset('apple')}/LaunchImage@2x.png'),
          isFalse,
        );
      });

      test('is the user\'s: it is never deleted, when the option goes off '
          'either', () async {
        await apply();
        project.write(
          'flavorizr.yaml',
          _config(flavors: {'apple': _icons['apple']!}),
        );

        await apply();

        expect(project.read(_storyboard('apple')), twoX);
        expect(
          project.read('${_imageset('apple')}/Contents.json'),
          '2.x contents',
        );
      });

      test('keeps its reference in the project', () async {
        project.write(
          _pbxproj,
          File(
            'test_resources/example_2x/ios/Runner.xcodeproj/project.pbxproj',
          ).readAsStringSync(),
        );

        await apply();

        expect(
          project.read(_pbxproj),
          contains('appleLaunchScreen.storyboard'),
        );

        project.write(
          'flavorizr.yaml',
          _config(flavors: {'apple': _icons['apple']!}),
        );
        await apply();

        expect(
          project.read(_pbxproj),
          contains('appleLaunchScreen.storyboard'),
        );
        expect(danglingUuids(project.read(_pbxproj)), isEmpty);
      });

      test('is not taken for a generated one when it only looks like '
          'a storyboard', () async {
        project.write(_storyboard('apple'), '<document/>');

        await apply();

        expect(project.read(_storyboard('apple')), '<document/>');
      });
    });
  });
}
