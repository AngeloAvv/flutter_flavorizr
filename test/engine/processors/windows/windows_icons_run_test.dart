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

import 'package:flutter_flavorizr/src/engine/lock/lock_store.dart';
import 'package:flutter_flavorizr/src/engine/ownership.dart';
import 'package:flutter_flavorizr/src/entrypoint/exit_codes.dart';
import 'package:flutter_flavorizr/src/entrypoint/processor_registry.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../../../entrypoint/cli_fixture.dart';

const _resources = 'windows/runner/resources';

String _ico(String flavor) => '$_resources/$flavor.ico';

/// A square icon of one colour.
List<int> _png(img.Color color, {int size = 1024}) =>
    img.encodePng(img.Image(width: size, height: size)..clear(color));

String _config(Map<String, String> flavors, {String root = ''}) =>
    '''
$root
flavors:
${[for (final MapEntry(:key, :value) in flavors.entries) '''
  $key:
    app:
      name: "$key"
$value    windows: {}
'''].join()}''';

const _appleIcon = '      icon: assets/apple.png\n';
const _bananaIcon = '      icon: assets/banana.png\n';
const _badge = '    badge: { label: DEV, color: "#E53935" }\n';

void main() {
  late CliFixture project;

  void put(String path, List<int> content) => File(project.abs(path))
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(content);

  setUp(() {
    project = CliFixture(android: false);
    put('assets/apple.png', _png(img.ColorRgb8(200, 30, 30)));
    put('assets/banana.png', _png(img.ColorRgb8(240, 220, 20)));
    put('$_resources/app_icon.ico', [9, 9, 9]);
  });
  tearDown(() => project.dispose());

  Future<int> apply([List<String> ids = const ['windows:icons']]) =>
      project.run(['apply', '--yes', ...ids]);

  void config(Map<String, String> flavors, {String root = ''}) =>
      project.write('flavorizr.yaml', _config(flavors, root: root));

  Uint8List bytes(String path) => File(project.abs(path)).readAsBytesSync();

  /// Every file of the project, by path, with its bytes.
  Map<String, List<int>> snapshot() => {
    for (final file in project.root.listSync(recursive: true).whereType<File>())
      p.relative(file.path, from: project.root.path): file.readAsBytesSync(),
  };

  Future<Set<String>> lockedFiles() async {
    final lock = (await LockStore(
      project.root,
      runningVersion: '3.0.0',
    ).read())!;

    return lock.processors['windows:icons']?.files.keys.toSet() ?? {};
  }

  /// The frames of the `.ico` of [flavor].
  List<img.Image> frames(String flavor) {
    final data = bytes(_ico(flavor));
    final decoder = img.IcoDecoder();
    final info = decoder.startDecode(data)!;

    return [
      for (var i = 0; i < info.numFrames; i++) decoder.decode(data, frame: i)!,
    ];
  }

  group('windows:icons', () {
    test('is a processor of the engine, and so are the dummy assets', () {
      final registry = ProcessorRegistry.standard();

      for (final id in ['windows:icons', 'windows:dummyAssets']) {
        expect(registry.engineProcessors, contains(id), reason: id);
      }
    });

    test('makes the .ico of each flavor that has an icon, at the four sizes, '
        'and records it as managed in the lock', () async {
      config({'apple': _appleIcon, 'banana': _bananaIcon, 'cherry': ''});

      final code = await apply();

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(frames('apple').map((frame) => frame.width), [16, 32, 48, 256]);
      expect(frames('banana').map((frame) => frame.width), [16, 32, 48, 256]);
      expect(project.exists(_ico('cherry')), isFalse);
      expect(bytes('$_resources/app_icon.ico'), [9, 9, 9]);

      final lock = (await LockStore(
        project.root,
        runningVersion: '3.0.0',
      ).read())!;
      final files = lock.processors['windows:icons']!.files;

      expect(files.keys.toSet(), {_ico('apple'), _ico('banana')});
      expect(
        files.values.map((file) => file.ownership),
        everyElement(Ownership.managed),
      );
    });

    test('takes the icon of the platform before the one of the app', () async {
      project.write(
        'flavorizr.yaml',
        'flavors:\n  apple:\n    app:\n      name: apple\n'
            '      icon: assets/apple.png\n'
            '    windows:\n      icon: assets/banana.png\n',
      );

      await apply();

      final pixel = frames('apple').last.getPixel(128, 128);

      expect([pixel.r, pixel.g, pixel.b], [240, 220, 20]);
    });

    test('changes nothing on a second run', () async {
      config({'apple': _appleIcon, 'banana': '$_bananaIcon$_badge'});
      await apply();
      final before = snapshot();

      final code = await apply();

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(snapshot(), before);
    });

    test(
      'writes nothing in a dry run, and shows the icon in the plan',
      () async {
        config({'apple': _appleIcon});
        final before = snapshot();

        final code = await project.run(['plan', 'windows:icons']);

        expect(code, ExitCodes.ok, reason: project.logger.output);
        expect(project.logger.output, contains(_ico('apple')));
        expect(snapshot(), before);
      },
    );

    test('status sees an icon that is gone from the project, and an icon that '
        'was edited, which it did not before the port', () async {
      config({'apple': _appleIcon});
      await apply();

      File(project.abs(_ico('apple'))).deleteSync();
      project.logger.lines.clear();

      expect(
        await project.run(['status', 'windows:icons']),
        ExitCodes.attention,
        reason: project.logger.output,
      );
      expect(project.logger.output, contains(_ico('apple')));
    });

    test('does nothing for the dummy assets, which 2.x built', () async {
      config({'apple': '', 'banana': _bananaIcon});
      final before = snapshot();

      final code = await apply(['windows:dummyAssets']);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(snapshot().keys.where((path) => path.endsWith('.ico')), [
        '$_resources/app_icon.ico',
      ]);
      expect(before.keys.where((path) => path.endsWith('.ico')), [
        '$_resources/app_icon.ico',
      ]);
    });

    test('is the same project whichever the order of the processors', () async {
      config({'apple': _appleIcon, 'banana': '$_bananaIcon$_badge'});
      await apply(['windows:dummyAssets', 'windows:icons']);
      final before = snapshot();

      final code = await apply(['windows:icons', 'windows:dummyAssets']);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(snapshot(), before);
    });

    test('makes nothing for a project with no Windows flavor', () async {
      project.write('flavorizr.yaml', CliFixture.config(['apple']));
      final before = snapshot();

      final code = await apply();

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(snapshot().keys.where((path) => path.endsWith('.ico')), [
        '$_resources/app_icon.ico',
      ]);
      expect(before.keys, contains('$_resources/app_icon.ico'));
    });

    test(
      'writes the icon again, and only it, when the source changes',
      () async {
        config({'apple': _appleIcon, 'banana': _bananaIcon});
        await apply();
        final apple = bytes(_ico('apple'));
        final banana = bytes(_ico('banana'));

        put('assets/apple.png', _png(img.ColorRgb8(1, 2, 3)));
        final code = await apply();

        expect(code, ExitCodes.ok, reason: project.logger.output);
        expect(bytes(_ico('apple')), isNot(apple));
        expect(bytes(_ico('banana')), banana);
      },
    );

    test('draws the badge on every size of the .ico, and only there', () async {
      config({'apple': _appleIcon, 'banana': '$_appleIcon$_badge'});

      final code = await apply();

      expect(code, ExitCodes.ok, reason: project.logger.output);

      for (final frame in frames('banana')) {
        // The corner of the band, at the bottom, has the colour of the badge.
        final corner = frame.getPixel(0, frame.height - 1);

        expect(
          [corner.r, corner.g, corner.b],
          [0xE5, 0x39, 0x35],
          reason: '${frame.width}',
        );
      }
      for (final frame in frames('apple')) {
        final corner = frame.getPixel(0, frame.height - 1);

        expect([corner.r, corner.g, corner.b], [200, 30, 30]);
      }
    });

    test('a badge makes an icon for a flavor with no icon, from the one of the '
        'root', () async {
      config({'apple': _badge}, root: 'icon: assets/apple.png');

      final code = await apply();

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(frames('apple').map((frame) => frame.width), [16, 32, 48, 256]);
    });

    group('what it makes no more', () {
      test('removes the .ico of a flavor that loses its icon, and keeps the '
          'others and the icon of the project', () async {
        config({'apple': _appleIcon, 'banana': _bananaIcon});
        await apply();

        config({'apple': '', 'banana': _bananaIcon});
        final code = await apply();

        expect(code, ExitCodes.ok, reason: project.logger.output);
        expect(project.exists(_ico('apple')), isFalse);
        expect(project.exists(_ico('banana')), isTrue);
        expect(bytes('$_resources/app_icon.ico'), [9, 9, 9]);
        expect(await lockedFiles(), {_ico('banana')});
      });

      test('removes the .ico of a flavor that is dropped', () async {
        config({'apple': _appleIcon, 'banana': _bananaIcon});
        await apply(['windows:dummyAssets', 'windows:icons']);

        config({'banana': _bananaIcon});
        final code = await apply(['windows:dummyAssets', 'windows:icons']);

        expect(code, ExitCodes.ok, reason: project.logger.output);
        expect(project.exists(_ico('apple')), isFalse);
        expect(project.exists(_ico('banana')), isTrue);
      });

      test('removes the .ico of a flavor that only has it for its badge, '
          'when the badge is turned off', () async {
        config({'apple': _badge}, root: 'icon: assets/apple.png');
        await apply();

        expect(project.exists(_ico('apple')), isTrue);

        config({'apple': ''}, root: 'icon: assets/apple.png');
        final code = await apply();

        expect(code, ExitCodes.ok, reason: project.logger.output);
        expect(project.exists(_ico('apple')), isFalse);
        expect(await lockedFiles(), isEmpty);
      });

      test('removes it when the badge comes from the root and a flavor turns '
          'it off', () async {
        config({
          'apple': '',
          'banana': '',
        }, root: 'icon: assets/apple.png\nbadge: true');
        await apply();

        expect(project.exists(_ico('apple')), isTrue);
        expect(project.exists(_ico('banana')), isTrue);

        config({
          'apple': '',
          'banana': '    badge: false\n',
        }, root: 'icon: assets/apple.png\nbadge: true');
        await apply();

        expect(project.exists(_ico('apple')), isTrue);
        expect(project.exists(_ico('banana')), isFalse);
      });

      test('makes the .ico again, as it was without the badge, when the badge '
          'of a flavor that has an icon is turned off', () async {
        config({'apple': _appleIcon});
        await apply();
        final plain = bytes(_ico('apple'));

        config({'apple': '$_appleIcon$_badge'});
        await apply();

        expect(bytes(_ico('apple')), isNot(plain));

        config({'apple': _appleIcon});
        final code = await apply();

        expect(code, ExitCodes.ok, reason: project.logger.output);
        expect(bytes(_ico('apple')), plain);
      });

      test('keeps the .ico of the user while the flavor has no icon and no '
          'badge', () async {
        put(_ico('apple'), [1, 2, 3]);
        config({'apple': ''});

        final code = await apply();

        expect(code, ExitCodes.ok, reason: project.logger.output);
        expect(bytes(_ico('apple')), [1, 2, 3]);
        expect(await lockedFiles(), isEmpty);
      });

      test('keeps the .ico of the user when the flavor is dropped', () async {
        put(_ico('apple'), [1, 2, 3]);
        config({'apple': '', 'banana': _bananaIcon});
        await apply();

        config({'banana': _bananaIcon});
        await apply();

        expect(bytes(_ico('apple')), [1, 2, 3]);
      });

      test(
        'removes only what it made: another file of the folder stays',
        () async {
          config({'apple': _appleIcon});
          await apply();
          put('$_resources/notes.txt', [4]);

          config({'apple': ''});
          final code = await apply();

          expect(code, ExitCodes.ok, reason: project.logger.output);
          expect(project.exists(_ico('apple')), isFalse);
          expect(bytes('$_resources/notes.txt'), [4]);
          expect(bytes('$_resources/app_icon.ico'), [9, 9, 9]);
        },
      );

      test(
        'shows the removal in the plan, and does not remove in a dry run',
        () async {
          config({'apple': _appleIcon});
          await apply();
          config({'apple': ''});

          await project.run(['plan', 'windows:icons']);

          expect(project.logger.output, contains(_ico('apple')));
          expect(project.exists(_ico('apple')), isTrue);
        },
      );

      test('does not remove the .ico in a run that does not select the '
          'processor', () async {
        config({'apple': _appleIcon});
        await apply();
        config({'apple': ''});

        final code = await apply(['windows:dummyAssets']);

        expect(code, ExitCodes.ok, reason: project.logger.output);
        expect(project.exists(_ico('apple')), isTrue);
        expect(await lockedFiles(), {_ico('apple')});
      });
    });

    group('conflicts and failures', () {
      test('is a conflict when an .ico was edited by hand, and nothing is '
          'written', () async {
        config({'apple': _appleIcon});
        await apply();
        put(_ico('apple'), [1, 2, 3]);
        put('assets/apple.png', _png(img.ColorRgb8(1, 2, 3)));
        final before = snapshot();

        final code = await apply();

        expect(code, ExitCodes.attention, reason: project.logger.output);
        expect(snapshot(), before);
      });

      test('does not overwrite the .ico of the user that the lock does not '
          'know, for a flavor that now has an icon', () async {
        put(_ico('apple'), [1, 2, 3]);
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

      test(
        'fails, and writes nothing, when the icon is not an image',
        () async {
          put('assets/banana.png', [1, 2, 3]);
          config({'apple': _appleIcon, 'banana': _bananaIcon});
          final before = snapshot();

          final code = await apply();

          expect(code, isNot(ExitCodes.ok));
          expect(snapshot(), before);
        },
      );

      test(
        'fails, and writes nothing, when the icon leaves the project',
        () async {
          config({
            'apple': _appleIcon,
            'banana': '      icon: ../outside.png\n',
          });
          final before = snapshot();

          final code = await apply();

          expect(code, isNot(ExitCodes.ok));
          expect(snapshot(), before);
        },
      );

      test('fails with a hint, and writes nothing, for a badge with no icon of '
          '512 px', () async {
        put('assets/small.png', _png(img.ColorRgb8(1, 2, 3), size: 64));
        config({
          'apple': _appleIcon,
          'banana': '      icon: assets/small.png\n$_badge',
        });
        final before = snapshot();

        final code = await apply();

        expect(code, isNot(ExitCodes.ok));
        expect(project.logger.output, contains('icon'));
        expect(snapshot(), before);
      });
    });
  });
}
