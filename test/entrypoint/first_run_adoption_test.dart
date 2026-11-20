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

import 'package:flutter_flavorizr/src/engine/lock/flavorizr_lock.dart';
import 'package:flutter_flavorizr/src/engine/lock/lock_store.dart';
import 'package:flutter_flavorizr/src/entrypoint/exit_codes.dart';
import 'package:test/test.dart';

import 'adopt_fixture.dart';
import 'cli_fixture.dart';

/// What the first run of 3.x does to a project 2.x flavorized, which has no
/// lock: the same as `adopt` and then the run, in one.
void main() {
  late CliFixture project;

  setUp(() => project = project2x());
  tearDown(() => project.dispose());

  /// What `plan` says for a project that was adopted explicitly first.
  Future<Map<String, String>> plannedAfterAdopt() async {
    final other = project2x();

    addTearDown(other.dispose);
    expect(await other.run(['adopt']), ExitCodes.ok);
    expect(other.exists('flavorizr.lock'), isTrue);

    return planned(other);
  }

  group('plan', () {
    test('shows the changes against the baseline the project is, and writes '
        'nothing, not even the lock', () async {
      final before = project.snapshot();

      final changes = await planned(project);

      expect(changes, await plannedAfterAdopt());
      expect(
        changes.values.where((change) => change.endsWith('/conflict')),
        isEmpty,
        reason: '$changes',
      );
      expect(project.snapshot(), before);
      expect(project.exists('flavorizr.lock'), isFalse);

      project.logger.lines.clear();

      expect(await project.run(['plan']), ExitCodes.ok);
      expect(project.logger.output, contains('There is no flavorizr.lock'));
      expect(project.logger.output, contains('flavorizr adopt'));
      expect(project.logger.output, contains('0 conflicts'));
      expect(project.exists('flavorizr.lock'), isFalse);
    });

    test('does not delete what the project is made of: only the dummy icons '
        'of 2.x', () async {
      final changes = await planned(project);

      expect(
        [
          for (final MapEntry(key: path, value: change) in changes.entries)
            if (change.startsWith('deleted/')) path,
        ],
        everyElement(anyOf(contains('AppIcon-apple'), contains('src/apple/'))),
      );
      expect(
        changes.keys.where((path) => path.contains('LaunchScreen')),
        isEmpty,
      );
    });

    test('of some processors adopts the whole project all the same', () async {
      final code = await project.run(['plan', 'android:icons']);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.exists('flavorizr.lock'), isFalse);
    });
  });

  group('status', () {
    test('says the lock is missing, and tells what to do', () async {
      final code = await project.run(['status']);

      expect(code, ExitCodes.attention);
      expect(project.logger.output, contains('flavorizr.lock does not exist'));
      expect(project.logger.output, contains('flavorizr adopt'));
      expect(project.exists('flavorizr.lock'), isFalse);
    });

    test('has no conflict to tell about', () async {
      await project.run(['status']);

      expect(project.logger.output, isNot(contains('edited by hand')));
    });
  });

  group('apply', () {
    test('adopts the project, shows its changes against that and writes them '
        'with the lock', () async {
      final code = await project.run(['apply', '--yes']);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.exists('flavorizr.lock'), isTrue);
      expect(project.logger.output, contains('There is no flavorizr.lock'));
      expect(project.logger.output, contains('0 conflicts'));

      final lock = (await lockOf(project))!;

      expect(lock.flavorNames, {'apple', 'banana'});
      // The dummy icons of 2.x went, and the ones of the user did not.
      expect(project.exists(icon('apple', 'hdpi')), isFalse);
      expect(project.exists(icon('banana', 'hdpi')), isTrue);
      expect(project.exists('ios/Runner/appleLaunchScreen.storyboard'), isTrue);
    });

    test(
      'is followed by a plan with nothing to do, and a status in sync',
      () async {
        await project.run(['apply', '--yes']);

        expect(await planned(project), isEmpty);
        expect(await project.run(['status']), ExitCodes.ok);
      },
    );

    test('writes nothing when it is not approved', () async {
      final before = project.snapshot();

      project.answer = false;

      final code = await project.run(['apply']);

      expect(code, ExitCodes.ok);
      expect(project.snapshot(), before);
      expect(project.exists('flavorizr.lock'), isFalse);
    });

    test(
      'of some processors records the whole project as the baseline',
      () async {
        final code = await project.run(['apply', '--yes', 'android:icons']);

        expect(code, ExitCodes.ok, reason: project.logger.output);

        final lock = (await lockOf(project))!;

        expect(lock.processors, contains('ios:xcconfig'));
        expect(lock.processors, contains('macos:schema'));
        expect(await planned(project), isNot(contains(icon('banana', 'hdpi'))));
      },
    );

    test('adopts the whole project, whatever the default recipe is', () async {
      final yaml = project.read('flavorizr.yaml');

      // The recipes are the last thing of the configuration.
      project.write(
        'flavorizr.yaml',
        '${yaml.substring(0, yaml.indexOf('recipes:'))}'
            'recipes:\n  default:\n    - android:icons\n',
      );

      final code = await project.run(['apply', '--yes', 'ios:xcconfig']);

      expect(code, ExitCodes.ok, reason: project.logger.output);

      final lock = (await lockOf(project))!;

      expect(lock.processors, contains('macos:schema'));
      expect(lock.processors, contains('android:icons'));
    });

    test('writes the lock when there is nothing else to write: a lost lock '
        'is recovered from the files', () async {
      await project.run(['apply', '--yes']);

      final lock = project.read('flavorizr.lock');

      File(project.abs('flavorizr.lock')).deleteSync();
      project.logger.lines.clear();

      final code = await project.run(['apply', '--yes']);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.logger.output, contains('There is no flavorizr.lock'));
      expect(project.logger.output, contains('are up to date'));
      expect(project.read('flavorizr.lock'), lock);
    });
  });

  group('a project of one platform', () {
    String only(String platform) =>
        'flavors:\n${[
          for (final flavor in ['apple', 'banana']) '''
  $flavor:
    app:
      name: "$flavor"
    $platform:
      bundleId: "com.example.$flavor"
''',
        ].join()}';

    for (final platform in ['ios', 'macos']) {
      test('$platform only is adopted for its platform', () async {
        project.write('flavorizr.yaml', only(platform));

        final changes = await planned(project);

        expect(
          changes.values.where((change) => change.endsWith('/conflict')),
          isEmpty,
          reason: '$changes',
        );

        expect(
          await project.run(['apply', '--yes']),
          ExitCodes.ok,
          reason: project.logger.output,
        );

        final lock = (await lockOf(project))!;

        expect(lock.processors, contains('$platform:xcconfig'));
        expect(
          lock.processors.keys.where((id) => id.startsWith('android:')),
          isEmpty,
        );
        expect(await planned(project), isEmpty);
      });
    }
  });

  group('when there is nothing to adopt', () {
    test(
      'a lock that records nothing is a lock: the project is not adopted',
      () async {
        await LockStore(
          project.root,
          runningVersion: '3.0.0',
        ).write(FlavorizrLock(flavorizrVersion: '3.0.0'));

        await project.run(['plan']);

        expect(
          project.logger.output,
          isNot(contains('There is no flavorizr.lock')),
        );
      },
    );

    test('a processor that fails to read the project fails the run, and '
        'writes nothing', () async {
      File(
        project.abs('.firebase/apple/GoogleService-Info.plist'),
      ).deleteSync();

      final before = project.snapshot();
      final code = await project.run(['apply', '--yes']);

      expect(code, ExitCodes.software, reason: project.logger.output);
      expect(project.snapshot(), before);
    });
  });

  group('a project flavorizr never ran on', () {
    late CliFixture fresh;

    setUp(() => fresh = CliFixture());
    tearDown(() => fresh.dispose());

    test('is not adopted: it is a first run, as it was', () async {
      final code = await fresh.run(['apply', '--yes', ...engineTargets]);

      expect(code, ExitCodes.ok, reason: fresh.logger.output);
      expect(fresh.exists('flavorizr.lock'), isTrue);
      expect(
        fresh.logger.output,
        isNot(contains('There is no flavorizr.lock')),
      );
    });

    test('is planned as it was', () async {
      final code = await fresh.run(['plan']);

      expect(code, ExitCodes.ok, reason: fresh.logger.output);
      expect(
        fresh.logger.output,
        isNot(contains('There is no flavorizr.lock')),
      );
    });
  });
}
