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

import 'package:flutter_flavorizr/src/engine/lock/flavorizr_lock.dart';
import 'package:flutter_flavorizr/src/engine/lock/lock_store.dart';
import 'package:flutter_flavorizr/src/engine/shadow/file_digest.dart';
import 'package:flutter_flavorizr/src/entrypoint/exit_codes.dart';
import 'package:test/test.dart';

import 'adopt_fixture.dart';
import 'cli_fixture.dart';

const _target = 'huawei:agconnect';
const _manifest = 'android/app/src/main/AndroidManifest.xml';

String _copy(String flavor) =>
    'android/app/src/$flavor/agconnect-services.json';

/// A configuration with an Android flavor for each of [flavors], of which
/// [withAgconnect] have an AppGallery Connect configuration.
String _config(
  Iterable<String> flavors, {
  Iterable<String> withAgconnect = const ['apple', 'banana'],
}) =>
    'flavors:\n${[for (final flavor in flavors) '''
  $flavor:
    app:
      name: "$flavor app"
    android:
      applicationId: "com.example.$flavor"
${withAgconnect.contains(flavor) ? '''
      agconnect:
        config: ".agconnect/$flavor/agconnect-services.json"
''' : ''}'''].join()}';

void main() {
  late CliFixture project;

  setUp(() {
    project = CliFixture();

    for (final flavor in ['apple', 'banana']) {
      project.write(
        '.agconnect/$flavor/agconnect-services.json',
        '$flavor-agconnect',
      );
    }
    project.write('flavorizr.yaml', _config(['apple', 'banana']));
  });
  tearDown(() => project.dispose());

  Future<int> apply([List<String> targets = const [_target]]) =>
      project.run(['apply', '--yes', ...targets]);

  Future<FlavorizrLock?> lock() =>
      LockStore(project.root, runningVersion: '3.0.0').read();

  group('huawei:agconnect', () {
    test('copies the configuration to the folder of each flavor that has '
        'one', () async {
      project.write(
        'flavorizr.yaml',
        _config(['apple', 'banana'], withAgconnect: ['apple']),
      );

      final code = await apply();

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.read(_copy('apple')), 'apple-agconnect');
      expect(project.exists(_copy('banana')), isFalse);
      expect(project.legacy.ids, isEmpty);
    });

    test(
      'runs on the engine: it is planned, and the lock is written',
      () async {
        expect(await project.run(['plan', _target]), ExitCodes.ok);
        expect(project.logger.output, contains(_copy('apple')));
        expect(project.logger.output, isNot(contains('not on the engine yet')));
        expect(project.exists(_copy('apple')), isFalse);
        expect(project.exists('flavorizr.lock'), isFalse);

        await apply();

        expect((await lock())!.processors, contains(_target));
      },
    );

    test('a re-run changes nothing', () async {
      await apply();
      final before = project.snapshot();

      final code = await apply();

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.snapshot(), before);
    });

    test('keeps the copies out of the lock as files, and the user changing '
        'them is never drift', () async {
      await project.run(['apply', '--yes']);

      final record = (await lock())!.processors[_target]!;

      expect(record.files, isEmpty);
      expect(
        record.keys.keys,
        unorderedEquals([_copy('apple'), _copy('banana')]),
      );

      project.write(_copy('apple'), 'edited');

      expect(
        await project.run(['status']),
        ExitCodes.ok,
        reason: project.logger.output,
      );
    });

    test('writes a copy again, silently, when the user changes it', () async {
      await apply();
      project.write(_copy('banana'), 'edited');
      project.write('.agconnect/banana/agconnect-services.json', 'new banana');

      final code = await apply();

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.read(_copy('banana')), 'new banana');
    });

    test('is in sync after it ran, and out of sync before', () async {
      expect(await project.run(['status']), isNot(ExitCodes.ok));

      await project.run(['apply', '--yes']);

      expect(await project.run(['status']), ExitCodes.ok);
    });

    test('removes the copy of a flavor that loses its configuration, and '
        'keeps the one of the other', () async {
      await apply();
      project.write(
        'flavorizr.yaml',
        _config(['apple', 'banana'], withAgconnect: ['apple']),
      );

      final code = await apply();

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.read(_copy('apple')), 'apple-agconnect');
      expect(project.exists(_copy('banana')), isFalse);
      expect((await lock())!.processors[_target]!.keys.keys, [_copy('apple')]);

      final before = project.snapshot();

      expect(await apply(), ExitCodes.ok);
      expect(project.snapshot(), before);
    });

    test('removes every copy, and the record, when no flavor has a '
        'configuration any more', () async {
      await apply();
      project.write(
        'flavorizr.yaml',
        _config(['apple', 'banana'], withAgconnect: []),
      );

      final code = await apply();

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.exists(_copy('apple')), isFalse);
      expect(project.exists(_copy('banana')), isFalse);
      expect((await lock())?.processors, isNot(contains(_target)));
      expect(project.exists(_manifest), isTrue);
    });

    test('removes the copy of a flavor that is removed, in a run of the whole '
        'project', () async {
      final run = ['apply', '--yes', ...engineTargets, _target];

      await project.run(run);
      project.write('flavorizr.yaml', _config(['apple']));

      final code = await project.run(run);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.read(_copy('apple')), 'apple-agconnect');
      expect(project.exists(_copy('banana')), isFalse);

      final before = project.snapshot();

      await project.run(run);

      expect(project.snapshot(), before);
    });

    test('leaves alone a file of the user in the folder of a flavor that has '
        'no configuration', () async {
      project.write(
        'flavorizr.yaml',
        _config(['apple', 'banana'], withAgconnect: ['apple']),
      );
      project.write(_copy('banana'), 'mine');

      await apply();
      project.write(
        'flavorizr.yaml',
        _config(['apple', 'banana'], withAgconnect: []),
      );
      await apply();

      expect(project.read(_copy('banana')), 'mine');
      expect(project.exists(_copy('apple')), isFalse);
    });

    test(
      'leaves alone a copy the user changed since, and forgets it',
      () async {
        await apply();
        project.write(_copy('banana'), 'mine now');
        project.write(
          'flavorizr.yaml',
          _config(['apple', 'banana'], withAgconnect: ['apple']),
        );

        final code = await apply();

        expect(code, ExitCodes.ok, reason: project.logger.output);
        expect(project.read(_copy('banana')), 'mine now');
        expect((await lock())!.processors[_target]!.keys.keys, [
          _copy('apple'),
        ]);
      },
    );

    test('does not delete what a lock names that is not where it makes a '
        'copy', () async {
      await apply();

      const inner = 'android/app/src/a/b/agconnect-services.json';
      const shallow = 'android/app/src/agconnect-services.json';
      const other = 'android/app/src/apple/other.json';
      const named = [_manifest, inner, shallow, other];
      final digest = digestOf(utf8.encode(project.read(_manifest)));
      final recorded = (await lock())!;

      for (final path in [inner, shallow, other]) {
        project.write(path, project.read(_manifest));
      }
      await LockStore(project.root, runningVersion: '3.0.0').write(
        FlavorizrLock(
          flavorizrVersion: recorded.flavorizrVersion,
          flavors: recorded.flavors,
          processors: {
            ...recorded.processors,
            _target: ProcessorLock(
              keys: {
                for (final path in named) path: {'copy': digest},
              },
            ),
          },
        ),
      );
      project.write(
        'flavorizr.yaml',
        _config(['apple', 'banana'], withAgconnect: []),
      );

      final code = await apply();

      expect(code, ExitCodes.ok, reason: project.logger.output);
      for (final path in named) {
        expect(project.exists(path), isTrue, reason: path);
      }
    });

    test('has nothing to do for a project with no configuration, and keeps '
        'what the user has', () async {
      project.write('flavorizr.yaml', _config(['apple'], withAgconnect: []));
      project.write(_copy('apple'), 'mine');
      final before = project.snapshot();

      final code = await apply();

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect({...project.snapshot()}..remove('flavorizr.lock'), before);
      expect((await lock())?.processors, isNot(contains(_target)));
    });

    test('fails when the configuration of a flavor is missing, and writes '
        'nothing', () async {
      File(
        project.abs('.agconnect/banana/agconnect-services.json'),
      ).deleteSync();
      final before = project.snapshot();

      final code = await apply();

      expect(code, isNot(ExitCodes.ok));
      expect(project.snapshot(), before);
      expect(project.exists(_copy('apple')), isFalse);
    });

    test('fails when the configuration of a flavor goes missing, and keeps '
        'what an earlier run made', () async {
      await apply();
      File(
        project.abs('.agconnect/banana/agconnect-services.json'),
      ).deleteSync();
      final before = project.snapshot();

      final code = await apply();

      expect(code, isNot(ExitCodes.ok));
      expect(project.snapshot(), before);
    });

    test('refuses a configuration outside the project', () async {
      project.write(
        'flavorizr.yaml',
        _config(['apple'], withAgconnect: []).replaceFirst(
          '      applicationId: "com.example.apple"\n',
          '      applicationId: "com.example.apple"\n'
              '      agconnect:\n        config: "../outside.json"\n',
        ),
      );
      final before = project.snapshot();

      final code = await apply();

      expect(code, isNot(ExitCodes.ok));
      expect(project.snapshot(), before);
    });

    test('refuses a configuration that is a folder, or a link out of the '
        'project, and writes nothing', () async {
      final outside = Directory.systemTemp.createTempSync('agconnect_outside_');
      addTearDown(() => outside.deleteSync(recursive: true));
      File('${outside.path}/agconnect-services.json').writeAsStringSync('x');
      Directory(
        project.abs('.agconnect/apple/folder'),
      ).createSync(recursive: true);
      Link(
        project.abs('.agconnect/apple/link.json'),
      ).createSync('${outside.path}/agconnect-services.json', recursive: true);

      for (final source in ['folder', 'link.json']) {
        project.write(
          'flavorizr.yaml',
          _config(['apple'], withAgconnect: []).replaceFirst(
            '      applicationId: "com.example.apple"\n',
            '      applicationId: "com.example.apple"\n'
                '      agconnect:\n        config: ".agconnect/apple/$source"\n',
          ),
        );
        final before = project.snapshot();

        final code = await apply();

        expect(code, isNot(ExitCodes.ok), reason: source);
        expect(project.snapshot(), before, reason: source);
      }
    }, skip: Platform.isWindows ? 'no links' : false);

    test('refuses a flavor that cannot be the name of a folder', () async {
      project.write(
        'flavorizr.yaml',
        'flavors:\n  "a/b":\n    app:\n      name: ab\n    android:\n'
            '      applicationId: com.example.ab\n      agconnect:\n'
            '        config: ".agconnect/apple/agconnect-services.json"\n',
      );
      final before = project.snapshot();

      final code = await apply();

      expect(code, isNot(ExitCodes.ok));
      expect(project.snapshot(), before);
    });

    test('a run of it leaves the lock of the others as it is, and a run of '
        'the others leaves its record', () async {
      await project.run(['apply', '--yes', ...engineTargets]);
      final before = (await lock())!;

      await apply();

      final after = (await lock())!;

      expect(after.processors[_target], isNotNull);
      for (final MapEntry(:key, :value) in before.processors.entries) {
        expect(after.processors[key], value, reason: key);
      }
      expect(after.flavors, before.flavors);

      await project.run(['apply', '--yes', 'android:icons']);

      expect((await lock())!.processors[_target], after.processors[_target]);
      expect(project.exists(_copy('apple')), isTrue);
    });

    test('is part of the default run, with no legacy step for it', () async {
      final code = await project.run(['apply', '--yes']);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.read(_copy('banana')), 'banana-agconnect');
      expect(project.legacy.ids, isNot(contains(_target)));
    });

    test('a default run with no configuration at all is in sync, and has no '
        'record', () async {
      project.write('flavorizr.yaml', _config(['apple'], withAgconnect: []));

      expect(await project.run(['apply', '--yes']), ExitCodes.ok);
      expect(await project.run(['status']), ExitCodes.ok);
      expect((await lock())!.processors, isNot(contains(_target)));
    });
  });

  group('adopt', () {
    test('does not record the copies 2.x made, and the next run takes them '
        'over', () async {
      final adopted = project2x();
      addTearDown(adopted.dispose);
      adopted.write(
        'flavorizr.yaml',
        adopted
            .read('flavorizr.yaml')
            .replaceFirst(
              '      applicationId: "com.example.apple"\n',
              '      applicationId: "com.example.apple"\n'
                  '      agconnect:\n        config: ".agconnect/x.json"\n',
            ),
      );
      adopted.write('.agconnect/x.json', 'agconnect');
      adopted.write(_copy('apple'), 'what 2.x copied');

      final code = await adopted.run(['adopt']);

      expect(code, ExitCodes.ok, reason: adopted.logger.output);
      expect((await lockOf(adopted))!.processors, isNot(contains(_target)));
      expect(adopted.read(_copy('apple')), 'what 2.x copied');

      final changes = await planned(adopted);

      expect(changes[_copy('apple')], 'modified/apply');
      expect(
        changes.values.where((change) => change.endsWith('/conflict')),
        isEmpty,
      );
    });
  });
}
