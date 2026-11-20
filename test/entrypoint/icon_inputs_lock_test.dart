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

import 'package:flutter_flavorizr/src/engine/lock/flavorizr_lock.dart';
import 'package:flutter_flavorizr/src/engine/lock/lock_codec.dart';
import 'package:flutter_flavorizr/src/engine/lock/lock_store.dart';
import 'package:flutter_flavorizr/src/engine/shadow/file_digest.dart';
import 'package:flutter_flavorizr/src/entrypoint/exit_codes.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'cli_fixture.dart';

const _resources = 'windows/runner/resources';
const _androidIcon = 'android/app/src/apple/res/mipmap-mdpi/ic_launcher.png';

String _ico(String flavor) => '$_resources/$flavor.ico';

List<int> _png(img.Color color, {int size = 1024}) =>
    img.encodePng(img.Image(width: size, height: size)..clear(color));

const _badge = '    badge: { label: DEV, color: "#E53935" }\n';

/// Windows flavors, `apple` with the icon of `assets/apple.png` and `banana`
/// with the one of `assets/banana.png`, plus [extra] lines for `apple`.
String _config({String apple = '', String banana = '', String root = ''}) =>
    '''
$root
flavors:
  apple:
    app:
      name: "apple"
      icon: assets/apple.png
$apple    windows: {}
  banana:
    app:
      name: "banana"
      icon: assets/banana.png
$banana    windows: {}
''';

/// What the icons processors do with the hash of the inputs of an icon, through
/// the whole pipeline: the executor, the diff, the lock and the CLI.
void main() {
  late CliFixture project;

  void put(String path, List<int> content) => File(project.abs(path))
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(content);

  Uint8List bytes(String path) => File(project.abs(path)).readAsBytesSync();

  Future<int> apply([List<String> ids = const ['windows:icons']]) =>
      project.run(['apply', '--yes', ...ids]);

  /// Every file of the project, by path, with its bytes.
  Map<String, List<int>> snapshot() => {
    for (final file in project.root.listSync(recursive: true).whereType<File>())
      p.relative(file.path, from: project.root.path): file.readAsBytesSync(),
  };

  LockStore store() => LockStore(project.root, runningVersion: '3.0.0');

  Future<ProcessorLock> windowsLock() async =>
      (await store().read())!.processors['windows:icons']!;

  String lockText() => project.read('flavorizr.lock');

  /// What a lock written on another machine, whose renderer made other bytes,
  /// looks like: the file is [content] and the lock says it was written so.
  Future<void> otherMachineMade(String path, List<int> content) async {
    put(path, content);

    final lock = (await store().read())!;
    final record = lock.processors['windows:icons']!;

    await store().write(
      FlavorizrLock(
        flavorizrVersion: lock.flavorizrVersion,
        flavors: lock.flavors,
        processors: {
          ...lock.processors,
          'windows:icons': ProcessorLock(
            files: {
              ...record.files,
              path: LockedFile(
                ownership: record.files[path]!.ownership,
                hash: digestOf(content),
              ),
            },
            inputs: record.inputs,
          ),
        },
      ),
    );
  }

  setUp(() {
    project = CliFixture(android: false, flavors: const []);
    put('assets/apple.png', _png(img.ColorRgb8(200, 30, 30)));
    put('assets/banana.png', _png(img.ColorRgb8(240, 220, 20)));
    put('$_resources/app_icon.ico', [9, 9, 9]);
    project.write('flavorizr.yaml', _config());
  });
  tearDown(() => project.dispose());

  group('the inputs of an icon in the lock', () {
    test('are recorded for every icon, next to its hash', () async {
      await apply();

      final record = await windowsLock();

      expect(record.files.keys.toSet(), {_ico('apple'), _ico('banana')});
      expect(record.inputs.keys.toSet(), record.files.keys.toSet());
      expect(
        record.inputs.values,
        everyElement(matches(RegExp(r'^sha256:[0-9a-f]{64}$'))),
      );
      expect(
        record.inputs[_ico('apple')],
        isNot(record.inputs[_ico('banana')]),
      );
      expect(lockText(), contains('schemaVersion: 2'));
    });

    test('are the inputs, never the output: the hash of the file is another '
        'one', () async {
      await apply();

      final record = await windowsLock();

      expect(
        record.inputs[_ico('apple')],
        isNot(record.files[_ico('apple')]!.hash),
      );
    });

    test('make a second run write the same lock, byte for byte', () async {
      await apply();
      final first = lockText();
      final icons = bytes(_ico('apple'));

      expect(await apply(), ExitCodes.ok, reason: project.logger.output);

      expect(lockText(), first);
      expect(bytes(_ico('apple')), icons);
    });

    test('do not depend on the path of the source image', () async {
      await apply();
      final before = (await windowsLock()).inputs;

      put('other/place/apple.png', bytes('assets/apple.png'));
      project.write(
        'flavorizr.yaml',
        _config().replaceFirst('assets/apple.png', 'other/place/apple.png'),
      );

      expect(await apply(), ExitCodes.ok, reason: project.logger.output);
      expect((await windowsLock()).inputs, before);
    });
  });

  group('an icon whose inputs did not change', () {
    test('is not rendered again, so what another machine made stays and the '
        'plan has nothing to say', () async {
      await apply();
      await otherMachineMade(_ico('apple'), [7, 7, 7]);
      final before = snapshot();

      project.logger.lines.clear();
      expect(
        await project.run(['plan', 'windows:icons']),
        ExitCodes.ok,
        reason: project.logger.output,
      );
      expect(project.logger.output, isNot(contains(_ico('apple'))));
      expect(await apply(), ExitCodes.ok, reason: project.logger.output);
      expect(bytes(_ico('apple')), [7, 7, 7]);
      expect(snapshot(), before);
    });

    test('is made again when the file was edited by hand, which is a conflict '
        'as it ever was', () async {
      await apply();
      put(_ico('apple'), [1, 2, 3]);
      final before = snapshot();

      final code = await apply();

      expect(code, ExitCodes.attention, reason: project.logger.output);
      expect(snapshot(), before);
    });

    test('is made again when it is gone', () async {
      await apply();
      final icon = bytes(_ico('apple'));
      File(project.abs(_ico('apple'))).deleteSync();

      expect(await apply(), ExitCodes.ok, reason: project.logger.output);
      expect(bytes(_ico('apple')), icon);
    });
  });

  group('an icon whose inputs changed', () {
    test('is made again, and only it', () async {
      await apply();
      final apple = bytes(_ico('apple'));
      final banana = bytes(_ico('banana'));
      final inputs = (await windowsLock()).inputs;

      put('assets/apple.png', _png(img.ColorRgb8(1, 2, 3)));

      expect(await apply(), ExitCodes.ok, reason: project.logger.output);
      expect(bytes(_ico('apple')), isNot(apple));
      expect(bytes(_ico('banana')), banana);

      final after = (await windowsLock()).inputs;

      expect(after[_ico('apple')], isNot(inputs[_ico('apple')]));
      expect(after[_ico('banana')], inputs[_ico('banana')]);
    });

    test('is made again, over what another machine made, when the source '
        'changes', () async {
      await apply();
      await otherMachineMade(_ico('apple'), [7, 7, 7]);

      put('assets/apple.png', _png(img.ColorRgb8(1, 2, 3)));

      expect(await apply(), ExitCodes.ok, reason: project.logger.output);
      expect(bytes(_ico('apple')), isNot([7, 7, 7]));
      expect(img.IcoDecoder().startDecode(bytes(_ico('apple')))!.numFrames, 4);
    });

    test('is made again with a badge, and as it was when the badge goes '
        'away', () async {
      await apply();
      final plain = bytes(_ico('apple'));
      final inputs = (await windowsLock()).inputs[_ico('apple')];

      project.write('flavorizr.yaml', _config(apple: _badge));
      expect(await apply(), ExitCodes.ok, reason: project.logger.output);
      expect(bytes(_ico('apple')), isNot(plain));
      expect((await windowsLock()).inputs[_ico('apple')], isNot(inputs));

      project.write('flavorizr.yaml', _config());
      expect(await apply(), ExitCodes.ok, reason: project.logger.output);
      expect(bytes(_ico('apple')), plain);
      expect((await windowsLock()).inputs[_ico('apple')], inputs);
    });

    test(
      'is made again when the label or the colour of the badge changes',
      () async {
        project.write('flavorizr.yaml', _config(apple: _badge));
        await apply();
        final inputs = (await windowsLock()).inputs[_ico('apple')];

        project.write(
          'flavorizr.yaml',
          _config(apple: '    badge: { label: QA, color: "#E53935" }\n'),
        );
        await apply();
        final label = (await windowsLock()).inputs[_ico('apple')];

        project.write(
          'flavorizr.yaml',
          _config(apple: '    badge: { label: QA, color: "#1E88E5" }\n'),
        );
        await apply();
        final color = (await windowsLock()).inputs[_ico('apple')];

        expect({inputs, label, color}, hasLength(3));
      },
    );

    test('is made from the new source when the flavor points at another '
        'image', () async {
      await apply();
      final banana = bytes(_ico('banana'));

      project.write(
        'flavorizr.yaml',
        _config().replaceFirst(
          'icon: assets/apple.png',
          'icon: assets/banana.png',
        ),
      );

      expect(await apply(), ExitCodes.ok, reason: project.logger.output);
      expect(bytes(_ico('apple')), banana);
    });
  });

  group('a source image', () {
    test('that is gone fails the run and writes nothing, even when the icon '
        'is up to date', () async {
      await apply();
      File(project.abs('assets/apple.png')).deleteSync();
      final before = snapshot();

      final code = await apply();

      expect(code, isNot(ExitCodes.ok));
      expect(snapshot(), before);
    });

    test('that is not an image fails the run when it changed', () async {
      await apply();
      put('assets/apple.png', [1, 2, 3]);
      final before = snapshot();

      final code = await apply();

      expect(code, isNot(ExitCodes.ok));
      expect(snapshot(), before);
    });
  });

  group('a lock from an earlier development build', () {
    test('without inputs is read, and rewritten with them on the next run, '
        'with no conflict and no change to the icons', () async {
      await apply();
      final lock = (await store().read())!;
      final record = lock.processors['windows:icons']!;
      final before = snapshot();

      await store().write(
        FlavorizrLock(
          flavorizrVersion: lock.flavorizrVersion,
          flavors: lock.flavors,
          processors: {
            ...lock.processors,
            'windows:icons': ProcessorLock(files: record.files),
          },
        ),
      );
      project.write(
        'flavorizr.lock',
        lockText().replaceFirst('schemaVersion: 2', 'schemaVersion: 1'),
      );

      expect(await apply(), ExitCodes.ok, reason: project.logger.output);
      expect(snapshot(), before);
      expect((await windowsLock()).inputs, record.inputs);
      expect(lockText(), contains('schemaVersion: 2'));
    });

    test('without inputs makes the icons again, so another machine finds '
        'the plan it expects', () async {
      await apply();
      await otherMachineMade(_ico('apple'), [7, 7, 7]);
      final lock = (await store().read())!;

      await store().write(
        FlavorizrLock(
          flavorizrVersion: lock.flavorizrVersion,
          flavors: lock.flavors,
          processors: {
            ...lock.processors,
            'windows:icons': ProcessorLock(
              files: lock.processors['windows:icons']!.files,
            ),
          },
        ),
      );

      expect(await apply(), ExitCodes.ok, reason: project.logger.output);
      expect(bytes(_ico('apple')), isNot([7, 7, 7]));
      expect((await windowsLock()).inputs, hasLength(2));
    });

    test(
      'of a newer schema is refused, with the file left as it was',
      () async {
        await apply();
        project.write(
          'flavorizr.lock',
          lockText().replaceFirst('schemaVersion: 2', 'schemaVersion: 3'),
        );
        final before = snapshot();

        final code = await apply();

        expect(code, isNot(ExitCodes.ok));
        expect(snapshot(), before);
      },
    );
  });

  group('adopting a project that has its icons and no lock', () {
    test('records the inputs of the icons that are what flavorizr makes from '
        'them, and not of the ones that differ', () async {
      await apply();

      final inputs = (await windowsLock()).inputs;

      File(project.abs('flavorizr.lock')).deleteSync();
      put(_ico('banana'), [4, 5, 6]);

      final code = await project.run(['adopt', 'windows:icons']);

      expect(code, ExitCodes.ok, reason: project.logger.output);

      final record = await windowsLock();

      expect(record.files.keys.toSet(), {_ico('apple'), _ico('banana')});
      expect(record.inputs, {_ico('apple'): inputs[_ico('apple')]});
      expect(bytes(_ico('banana')), [4, 5, 6]);
    });

    test('is followed by a run that makes the icons that differ, with no '
        'conflict, and records their inputs', () async {
      await apply();

      final inputs = (await windowsLock()).inputs;
      final banana = bytes(_ico('banana'));

      File(project.abs('flavorizr.lock')).deleteSync();
      put(_ico('banana'), [4, 5, 6]);
      await project.run(['adopt', 'windows:icons']);

      expect(await apply(), ExitCodes.ok, reason: project.logger.output);
      expect(bytes(_ico('banana')), banana);
      expect((await windowsLock()).inputs, inputs);
    });

    test('is the first run when the project has no 2.x files: the icons that '
        'are as flavorizr makes them are recorded with their inputs', () async {
      await apply();

      final before = lockText();

      File(project.abs('flavorizr.lock')).deleteSync();

      expect(await apply(), ExitCodes.ok, reason: project.logger.output);
      expect(lockText(), before);
    });
  });

  group('a run of other processors', () {
    test('keeps the inputs of the icons it did not run', () async {
      project.write('flavorizr.yaml', '''
flavors:
  apple:
    app:
      name: apple
      icon: assets/apple.png
    android:
      applicationId: com.example.apple
    windows: {}
''');
      expect(
        await apply(['android:icons', 'windows:icons']),
        ExitCodes.ok,
        reason: project.logger.output,
      );
      final before = (await store().read())!;

      put('assets/apple.png', _png(img.ColorRgb8(1, 2, 3)));
      expect(await apply(['windows:icons']), ExitCodes.ok);

      final after = (await store().read())!;

      expect(
        after.processors['android:icons'],
        before.processors['android:icons'],
      );
      expect(
        after.processors['android:icons']!.inputs.keys,
        contains(_androidIcon),
      );
      expect(
        after.processors['windows:icons']!.inputs[_ico('apple')],
        isNot(before.processors['windows:icons']!.inputs[_ico('apple')]),
      );
    });

    test('lose the inputs of the icons of a flavor that is dropped', () async {
      await apply();

      project.write(
        'flavorizr.yaml',
        _config().replaceAll(RegExp(r'  banana:[\s\S]*'), ''),
      );

      expect(await apply(), ExitCodes.ok, reason: project.logger.output);
      expect(project.exists(_ico('banana')), isFalse);
      expect((await windowsLock()).inputs.keys, [_ico('apple')]);
    });
  });

  test('the lock is the same on every machine: no time, no path of the '
      'machine', () async {
    await apply();

    final text = lockText();

    expect(text, isNot(contains(project.root.path)));
    // Read and written again, it is the same bytes.
    expect(
      LockCodec.encode(LockCodec.decode(text, runningVersion: '3.0.0')),
      text,
    );
  });
}
