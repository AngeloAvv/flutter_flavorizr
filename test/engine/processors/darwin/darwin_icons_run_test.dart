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
import 'package:flutter_flavorizr/src/engine/ownership.dart';
import 'package:flutter_flavorizr/src/entrypoint/exit_codes.dart';
import 'package:flutter_flavorizr/src/entrypoint/processor_registry.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../../../entrypoint/cli_fixture.dart';
import '../../darwin/pristine_project.dart';

/// What differs between iOS and macOS.
class _Platform {
  final String name;
  final String assets;
  final String icon;

  const _Platform(this.name, this.assets, this.icon);

  String id(String suffix) => '$name:$suffix';
  String set(String flavor) => '$assets/AppIcon-$flavor.appiconset';
  String file(String flavor, [String? name]) =>
      '${set(flavor)}/${name ?? icon}';
}

const _ios = _Platform(
  'ios',
  'ios/Runner/Assets.xcassets',
  'Icon-App-1024x1024@1x.png',
);
const _macos = _Platform(
  'macos',
  'macos/Runner/Assets.xcassets',
  'app_icon_1024.png',
);

/// A square icon of one colour.
List<int> _png(img.Color color, {int size = 1024}) =>
    img.encodePng(img.Image(width: size, height: size)..clear(color));

String _config(
  _Platform platform,
  Map<String, String> flavors, {
  String root = '',
}) =>
    '''
$root
flavors:
${[for (final MapEntry(:key, :value) in flavors.entries) '''
  $key:
    app:
      name: "$key"
${value.replaceAll('{p}', platform.name)}    ${platform.name}:
      bundleId: "com.example.$key"
'''].join()}''';

const _appleIcon = '      icon: assets/apple.png\n';
const _bananaIcon = '      icon: assets/banana.png\n';
const _badge = '    badge: { label: DEV, color: "#E53935" }\n';

void main() {
  late CliFixture project;
  late Directory temp;

  void put(String path, List<int> content) => File(project.abs(path))
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(content);

  setUpAll(() {
    temp = Directory.systemTemp.createTempSync('flavorizr_darwin_icons_run_');
  });
  tearDownAll(() => temp.deleteSync(recursive: true));

  setUp(() {
    project = CliFixture(android: false);
    put('assets/apple.png', _png(img.ColorRgb8(200, 30, 30)));
    put('assets/banana.png', _png(img.ColorRgb8(240, 220, 20)));
  });
  tearDown(() => project.dispose());

  Uint8List bytes(String path) => File(project.abs(path)).readAsBytesSync();

  /// Every file of the project, by path, with its bytes.
  Map<String, List<int>> snapshot() => {
    for (final file in project.root.listSync(recursive: true).whereType<File>())
      p.relative(file.path, from: project.root.path): file.readAsBytesSync(),
  };

  Future<Set<String>> lockedFiles(String processor) async {
    final lock = (await LockStore(
      project.root,
      runningVersion: '3.0.0',
    ).read())!;

    return lock.processors[processor]?.files.keys.toSet() ?? {};
  }

  for (final platform in [_ios, _macos]) {
    group('${platform.name}:icons', () {
      Future<int> apply([List<String> extra = const []]) =>
          project.run(['apply', '--yes', ...extra, platform.id('icons')]);

      void config(Map<String, String> flavors, {String root = ''}) => project
          .write('flavorizr.yaml', _config(platform, flavors, root: root));

      test('is a processor of the engine, and so are the dummy assets', () {
        final registry = ProcessorRegistry.standard();

        for (final id in [platform.id('icons'), platform.id('dummyAssets')]) {
          expect(registry.engineProcessors, contains(id), reason: id);
        }
      });

      test('makes the set of each flavor that has an icon, and records it as '
          'managed in the lock', () async {
        config({'apple': _appleIcon, 'banana': _bananaIcon, 'cherry': ''});

        final code = await apply();

        expect(code, ExitCodes.ok, reason: project.logger.output);
        expect(project.exists(platform.file('apple')), isTrue);
        expect(project.exists(platform.file('banana')), isTrue);
        expect(project.exists(platform.set('cherry')), isFalse);

        final lock = (await LockStore(
          project.root,
          runningVersion: '3.0.0',
        ).read())!;
        final files = lock.processors[platform.id('icons')]!.files;

        expect(files.keys, contains(platform.file('apple', 'Contents.json')));
        expect(files.keys, contains(platform.file('banana')));
        expect(
          files.values.map((file) => file.ownership),
          everyElement(Ownership.managed),
        );
        expect(files.keys.where((path) => path.contains('cherry')), isEmpty);
      });

      test('changes nothing on a second run', () async {
        config({'apple': _appleIcon, 'banana': '$_bananaIcon$_badge'});
        await apply();
        final before = snapshot();

        final code = await apply();

        expect(code, ExitCodes.ok, reason: project.logger.output);
        expect(snapshot(), before);
      });

      test('writes nothing in a dry run', () async {
        config({'apple': _appleIcon});

        final code = await project.run(['plan', platform.id('icons')]);

        expect(code, ExitCodes.ok, reason: project.logger.output);
        expect(project.exists(platform.set('apple')), isFalse);
      });

      test('does nothing for the dummy assets, which 2.x copied', () async {
        config({'apple': '', 'banana': _bananaIcon});

        final code = await project.run([
          'apply',
          '--yes',
          platform.id('dummyAssets'),
        ]);

        expect(code, ExitCodes.ok, reason: project.logger.output);
        expect(project.exists(platform.assets), isFalse);
      });

      test(
        'is the same project whichever the order of the processors',
        () async {
          config({'apple': _appleIcon, 'banana': '$_bananaIcon$_badge'});
          await project.run([
            'apply',
            '--yes',
            platform.id('dummyAssets'),
            platform.id('icons'),
          ]);
          final before = snapshot();

          final code = await project.run([
            'apply',
            '--yes',
            platform.id('icons'),
            platform.id('dummyAssets'),
          ]);

          expect(code, ExitCodes.ok, reason: project.logger.output);
          expect(snapshot(), before);
        },
      );

      test(
        'writes the icons again, and only them, when the source changes',
        () async {
          config({'apple': _appleIcon, 'banana': _bananaIcon});
          await apply();
          final banana = bytes(platform.file('banana'));
          final apple = bytes(platform.file('apple'));

          put('assets/apple.png', _png(img.ColorRgb8(1, 2, 3)));
          final code = await apply();

          expect(code, ExitCodes.ok, reason: project.logger.output);
          expect(bytes(platform.file('apple')), isNot(apple));
          expect(bytes(platform.file('banana')), banana);
        },
      );

      test('removes the set of a flavor that loses its icon, with its folder, '
          'and keeps the others', () async {
        config({'apple': _appleIcon, 'banana': _bananaIcon});
        await apply();

        config({'apple': '', 'banana': _bananaIcon});
        final code = await apply();

        expect(code, ExitCodes.ok, reason: project.logger.output);
        expect(project.exists(platform.set('apple')), isFalse);
        expect(project.exists(platform.file('banana')), isTrue);
        expect(
          await lockedFiles(platform.id('icons')),
          everyElement(contains('banana')),
        );
      });

      test('removes the set of a flavor that is dropped', () async {
        config({'apple': _appleIcon, 'banana': _bananaIcon});
        await apply();

        config({'banana': _bananaIcon});
        final code = await apply();

        expect(code, ExitCodes.ok, reason: project.logger.output);
        expect(project.exists(platform.set('apple')), isFalse);
        expect(project.exists(platform.file('banana')), isTrue);
      });

      test('removes the icons of a flavor that only has them for its badge, '
          'when the badge is turned off', () async {
        config({'apple': _badge}, root: 'icon: assets/apple.png');
        await apply();

        expect(project.exists(platform.file('apple')), isTrue);

        config({'apple': ''}, root: 'icon: assets/apple.png');
        final code = await apply();

        expect(code, ExitCodes.ok, reason: project.logger.output);
        expect(project.exists(platform.set('apple')), isFalse);
        expect(await lockedFiles(platform.id('icons')), isEmpty);
      });

      test('removes them when the badge comes from the root and a flavor '
          'turns it off', () async {
        config({
          'apple': '',
          'banana': '',
        }, root: 'icon: assets/apple.png\nbadge: true');
        await apply();

        expect(project.exists(platform.set('apple')), isTrue);
        expect(project.exists(platform.set('banana')), isTrue);

        config({
          'apple': '',
          'banana': '    badge: false\n',
        }, root: 'icon: assets/apple.png\nbadge: true');
        await apply();

        expect(project.exists(platform.set('apple')), isTrue);
        expect(project.exists(platform.set('banana')), isFalse);
      });

      test('keeps the icons of a flavor that has an icon when its badge is '
          'turned off, as they were without it', () async {
        config({'apple': _appleIcon});
        await apply();
        final plain = bytes(platform.file('apple'));

        config({'apple': '$_appleIcon$_badge'});
        await apply();

        expect(bytes(platform.file('apple')), isNot(plain));

        config({'apple': _appleIcon});
        final code = await apply();

        expect(code, ExitCodes.ok, reason: project.logger.output);
        expect(bytes(platform.file('apple')), plain);
      });

      test('removes only what it made: a file of the user in the set stays, '
          'and so does the folder', () async {
        config({'apple': _appleIcon});
        await apply();
        project.write('${platform.set('apple')}/notes.txt', 'mine');

        config({'apple': ''});
        final code = await apply();

        expect(code, ExitCodes.ok, reason: project.logger.output);
        expect(project.read('${platform.set('apple')}/notes.txt'), 'mine');
        expect(project.exists(platform.file('apple')), isFalse);
        expect(
          project.exists(platform.file('apple', 'Contents.json')),
          isFalse,
        );
      });

      test('is a conflict when an icon was edited by hand, and nothing is '
          'written', () async {
        config({'apple': _appleIcon});
        await apply();
        put(platform.file('apple'), [1, 2, 3]);
        put('assets/apple.png', _png(img.ColorRgb8(1, 2, 3)));
        final before = snapshot();

        final code = await apply();

        expect(code, ExitCodes.attention, reason: project.logger.output);
        expect(snapshot(), before);
      });

      test(
        'leaves the set of the user alone for a flavor with no icon',
        () async {
          project.write(platform.file('apple', 'Contents.json'), '{"mine":1}');
          config({'apple': ''});

          final code = await apply();

          expect(code, ExitCodes.ok, reason: project.logger.output);
          expect(
            project.read(platform.file('apple', 'Contents.json')),
            '{"mine":1}',
          );
        },
      );

      test('does not overwrite the set of the user that the lock does not '
          'know, for a flavor that now has an icon', () async {
        project.write(platform.file('apple', 'Contents.json'), '{"mine":1}');
        config({'apple': _appleIcon});
        final before = snapshot();

        final code = await apply();

        expect(code, ExitCodes.attention, reason: project.logger.output);
        expect(snapshot(), before);
      });

      test('fails, and writes nothing, when the icon is missing', () async {
        config({
          'apple': _appleIcon,
          'banana': '      icon: assets/gone.png\n',
        });
        final before = snapshot();

        final code = await apply();

        expect(code, isNot(ExitCodes.ok));
        expect(snapshot(), before);
      });
    });
  }

  group('ios:icons with ios:buildTargets', () {
    late String pristine;
    const pbxproj = 'ios/Runner.xcodeproj/project.pbxproj';

    setUp(() async {
      pristine = await pristineIosPbxproj(temp);
      project.write(pbxproj, pristine);
    });

    Future<String?> appIconOf(String flavor) async {
      final xcodeproj = await XcodeProject.open(
        project.abs('ios/Runner.xcodeproj'),
      );
      final config = xcodeproj.buildConfigurationList['Debug-$flavor']!;

      return config.buildSettings['ASSETCATALOG_COMPILER_APPICON_NAME']
          as String?;
    }

    Future<int> apply(List<String> ids) =>
        project.run(['apply', '--yes', ...ids]);

    test('a flavor that loses its icon builds with the AppIcon of the project '
        'in the run that removes its set', () async {
      project.write('flavorizr.yaml', _config(_ios, {'apple': _appleIcon}));
      await apply(['ios:buildTargets', 'ios:icons']);

      expect(await appIconOf('apple'), r'AppIcon-$(ASSET_PREFIX)');
      expect(project.exists(_ios.set('apple')), isTrue);

      project.write('flavorizr.yaml', _config(_ios, {'apple': ''}));
      final code = await apply(['ios:buildTargets', 'ios:icons']);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.exists(_ios.set('apple')), isFalse);
      expect(await appIconOf('apple'), 'AppIcon');
    });

    test(
      'the same goes when the processors run apart, in either order',
      () async {
        project.write('flavorizr.yaml', _config(_ios, {'apple': _appleIcon}));
        await apply(['ios:icons']);
        await apply(['ios:buildTargets']);

        expect(await appIconOf('apple'), r'AppIcon-$(ASSET_PREFIX)');

        project.write('flavorizr.yaml', _config(_ios, {'apple': ''}));
        await apply(['ios:buildTargets']);

        expect(await appIconOf('apple'), 'AppIcon');

        await apply(['ios:icons']);

        expect(project.exists(_ios.set('apple')), isFalse);
        expect(await appIconOf('apple'), 'AppIcon');
      },
    );

    test('a set of the user that the lock does not know is still the set of '
        'the flavor', () async {
      project.write('${_ios.set('apple')}/Contents.json', '{"mine":1}');
      project.write('flavorizr.yaml', _config(_ios, {'apple': ''}));

      await apply(['ios:buildTargets', 'ios:icons']);

      expect(await appIconOf('apple'), r'AppIcon-$(ASSET_PREFIX)');
      expect(project.read(_ios.file('apple', 'Contents.json')), '{"mine":1}');
    });

    test('a flavor with a badge and no icon builds with its own set', () async {
      project.write(
        'flavorizr.yaml',
        _config(_ios, {'apple': _badge}, root: 'icon: assets/apple.png'),
      );

      await apply(['ios:buildTargets', 'ios:icons']);

      expect(await appIconOf('apple'), r'AppIcon-$(ASSET_PREFIX)');
      expect(project.exists(_ios.file('apple')), isTrue);
    });
  });
}
