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

import 'package:dart_xcodeproj/dart_xcodeproj.dart';
import 'package:flutter_flavorizr/src/engine/darwin/owned_build_settings.dart';
import 'package:flutter_flavorizr/src/engine/lock/flavorizr_lock.dart';
import 'package:flutter_flavorizr/src/engine/lock/lock_store.dart';
import 'package:flutter_flavorizr/src/entrypoint/exit_codes.dart';
import 'package:flutter_flavorizr/src/entrypoint/processor_registry.dart';
import 'package:test/test.dart';

import '../../../entrypoint/cli_fixture.dart';
import '../../darwin/pbxproj_integrity.dart';
import '../../darwin/pristine_project.dart';

const _iosProject = 'ios/Runner.xcodeproj';
const _iosPbxproj = '$_iosProject/project.pbxproj';
const _macosProject = 'macos/Runner.xcodeproj';

String _config(
  Iterable<String> flavors, {
  String ios = '',
  String bundleId = 'com.example',
}) =>
    'flavors:\n${[for (final flavor in flavors) '''
  "$flavor":
    app:
      name: "${flavor[0].toUpperCase()}${flavor.substring(1)} App"
    ios:
      bundleId: "$bundleId.$flavor"
$ios'''].join()}';

/// The `buildSettings` of a flavor of the yaml.
String _settings(Map<String, String> settings) =>
    '      buildSettings:\n'
    '${[for (final entry in settings.entries) '        ${entry.key}: "${entry.value}"\n'].join()}';

void main() {
  late CliFixture project;
  late Directory temp;
  late String pristine;

  Future<int> apply([List<String> extra = const []]) =>
      project.run(['apply', '--yes', ...extra, 'ios:buildTargets']);

  Future<XcodeProject> open() => XcodeProject.open(project.abs(_iosProject));

  /// Edits the project the way Xcode would, and saves it.
  Future<void> edit(void Function(XcodeProject xcodeproj) change) async {
    final xcodeproj = await open();

    change(xcodeproj);
    await xcodeproj.save();
  }

  XCBuildConfiguration projectConfig(XcodeProject xcodeproj, String name) =>
      xcodeproj.buildConfigurationList[name]!;

  XCBuildConfiguration targetConfig(XcodeProject xcodeproj, String name) =>
      xcodeproj.nativeTargets.first.buildConfigurationList![name]!;

  /// The name the lock gives to a setting of a configuration.
  Future<String> keyOf(String scope, String name, String setting) async {
    final xcodeproj = await open();
    final config = scope == OwnedBuildSettings.projectScope
        ? projectConfig(xcodeproj, name)
        : targetConfig(xcodeproj, name);

    return OwnedBuildSettings.keyOf(scope, config.uuid, setting);
  }

  setUpAll(() {
    temp = Directory.systemTemp.createTempSync('flavorizr_build_targets_');
  });
  tearDownAll(() => temp.deleteSync(recursive: true));

  setUp(() async {
    pristine = await pristineIosPbxproj(temp);
    project = CliFixture(android: false);
    project.write('flavorizr.yaml', _config(['dev']));
    project.write(_iosPbxproj, pristine);
  });
  tearDown(() => project.dispose());

  Future<ProcessorLock> locked([
    String processor = 'ios:buildTargets',
    CliFixture? of,
  ]) async {
    final lock = (await LockStore(
      (of ?? project).root,
      runningVersion: '3.0.0',
    ).read())!;

    return lock.processors[processor]!;
  }

  group('ios:buildTargets', () {
    test('is a processor of the engine, in the recipe of iOS', () {
      final registry = ProcessorRegistry.standard();

      expect(registry.isEngine('ios:buildTargets'), isTrue);
      expect(registry.isEngine('macos:buildTargets'), isTrue);
      expect(registry.legacyIds, isNot(contains('ios:buildTargets')));
    });

    test('makes the configurations of the flavor, with its settings', () async {
      final code = await apply();

      expect(code, ExitCodes.ok, reason: project.logger.output);

      final xcodeproj = await open();

      for (final mode in ['Debug', 'Profile', 'Release']) {
        final config = projectConfig(xcodeproj, '$mode-dev');

        expect(
          config.buildSettings['PRODUCT_BUNDLE_IDENTIFIER'],
          'com.example.dev',
        );
        expect(config.buildSettings['SWIFT_VERSION'], '5.0');
        expect(config.buildSettings['FRAMEWORK_SEARCH_PATHS'], [
          r'$(inherited)',
          r'$(PROJECT_DIR)/Flutter',
        ]);
        expect(targetConfig(xcodeproj, '$mode-dev').buildSettings, {
          'PRODUCT_NAME': r'$(TARGET_NAME)',
        });
        expect(
          config.baseConfigurationReference?.path,
          'Flutter/dev$mode.xcconfig',
        );
      }
      expect(
        project.read(_iosPbxproj),
        isNot(matches(RegExp(r'dev\w*\.xcconfig in Resources'))),
        reason: 'the xcconfig files are never resources',
      );
      expect(danglingUuids(project.read(_iosPbxproj)), isEmpty);
    });

    test('records the settings it wrote, key by key, in the lock', () async {
      await apply();

      final keys = (await locked()).keys[_iosPbxproj]!;

      final swift = await keyOf('project', 'Debug-dev', 'SWIFT_VERSION');

      expect(
        keys.keys,
        containsAll([
          swift,
          await keyOf('project', 'Release-dev', 'PRODUCT_BUNDLE_IDENTIFIER'),
          await keyOf('target', 'Profile-dev', 'PRODUCT_NAME'),
        ]),
      );
      expect(keys[swift], OwnedBuildSettings.hashOf('5.0'));
      expect(keys.keys, everyElement(isNot(contains('DEVELOPMENT_TEAM'))));
    });

    test('changes nothing on a second run', () async {
      await apply();
      final before = project.snapshot();

      final code = await apply();

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.snapshot(), before);
    });

    test('writes nothing in a dry run', () async {
      final before = project.snapshot();

      final code = await project.run(['plan', 'ios:buildTargets']);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.snapshot(), before);
    });

    group('keeps the settings of the user', () {
      test(
        'a DEVELOPMENT_TEAM chosen in Xcode survives a run (#340)',
        () async {
          await apply();
          await edit((xcodeproj) {
            for (final mode in ['Debug', 'Profile', 'Release']) {
              targetConfig(xcodeproj, '$mode-dev').buildSettings = {
                ...targetConfig(xcodeproj, '$mode-dev').buildSettings,
                'DEVELOPMENT_TEAM': 'ABCDE12345',
                'CODE_SIGN_STYLE': 'Automatic',
              };
            }
            projectConfig(xcodeproj, 'Debug-dev').buildSettings = {
              ...projectConfig(xcodeproj, 'Debug-dev').buildSettings,
              'DEVELOPMENT_TEAM': 'FGHIJ67890',
            };
          });

          final code = await apply();

          expect(code, ExitCodes.ok, reason: project.logger.output);

          final xcodeproj = await open();

          for (final mode in ['Debug', 'Profile', 'Release']) {
            expect(targetConfig(xcodeproj, '$mode-dev').buildSettings, {
              'PRODUCT_NAME': r'$(TARGET_NAME)',
              'DEVELOPMENT_TEAM': 'ABCDE12345',
              'CODE_SIGN_STYLE': 'Automatic',
            }, reason: mode);
          }
          expect(
            projectConfig(
              xcodeproj,
              'Debug-dev',
            ).buildSettings['DEVELOPMENT_TEAM'],
            'FGHIJ67890',
          );
          expect(
            projectConfig(
              xcodeproj,
              'Debug-dev',
            ).buildSettings['SWIFT_VERSION'],
            '5.0',
          );
        },
      );

      test('a DEVELOPMENT_TEAM survives a change of the yaml, with no '
          'conflict', () async {
        await apply();
        await edit((xcodeproj) {
          targetConfig(xcodeproj, 'Debug-dev').buildSettings = {
            ...targetConfig(xcodeproj, 'Debug-dev').buildSettings,
            'DEVELOPMENT_TEAM': 'ABCDE12345',
          };
        });
        project.write(
          'flavorizr.yaml',
          _config(['dev'], bundleId: 'it.example'),
        );

        final code = await apply();

        expect(code, ExitCodes.ok, reason: project.logger.output);

        final xcodeproj = await open();

        expect(
          targetConfig(
            xcodeproj,
            'Debug-dev',
          ).buildSettings['DEVELOPMENT_TEAM'],
          'ABCDE12345',
        );
        expect(
          projectConfig(
            xcodeproj,
            'Debug-dev',
          ).buildSettings['PRODUCT_BUNDLE_IDENTIFIER'],
          'it.example.dev',
        );
      });

      test('a DEVELOPMENT_TEAM is kept when the lock is lost', () async {
        await apply();
        await edit((xcodeproj) {
          targetConfig(xcodeproj, 'Debug-dev').buildSettings = {
            ...targetConfig(xcodeproj, 'Debug-dev').buildSettings,
            'DEVELOPMENT_TEAM': 'ABCDE12345',
          };
        });
        File(project.abs('flavorizr.lock')).deleteSync();

        final code = await apply();

        expect(code, ExitCodes.ok, reason: project.logger.output);
        expect(
          targetConfig(await open(), 'Debug-dev').buildSettings,
          containsPair('DEVELOPMENT_TEAM', 'ABCDE12345'),
        );
      });
    });

    group('removes the settings that are not wanted anymore', () {
      setUp(() {
        project.write(
          'flavorizr.yaml',
          _config(['dev'], ios: _settings({'MY_SETTING': 'one'})),
        );
      });

      test('a setting that left the yaml leaves the project, and only '
          'that', () async {
        await apply();

        expect(
          projectConfig(await open(), 'Debug-dev').buildSettings,
          containsPair('MY_SETTING', 'one'),
        );

        project.write('flavorizr.yaml', _config(['dev']));
        final code = await apply();

        expect(code, ExitCodes.ok, reason: project.logger.output);

        final xcodeproj = await open();

        for (final mode in ['Debug', 'Profile', 'Release']) {
          final settings = projectConfig(xcodeproj, '$mode-dev').buildSettings;

          expect(settings, isNot(contains('MY_SETTING')), reason: mode);
          expect(settings['SWIFT_VERSION'], '5.0', reason: mode);
        }
        expect(
          (await locked()).keys[_iosPbxproj]!.keys,
          isNot(contains(await keyOf('project', 'Debug-dev', 'MY_SETTING'))),
        );
      });

      test(
        'but not when somebody changed the value: it is theirs now, and '
        'a hand edit of what flavorizr wrote is for the user to say',
        () async {
          await apply();
          await edit((xcodeproj) {
            projectConfig(xcodeproj, 'Debug-dev').buildSettings = {
              ...projectConfig(xcodeproj, 'Debug-dev').buildSettings,
              'MY_SETTING': 'mine',
            };
          });
          project.write('flavorizr.yaml', _config(['dev']));

          final conflicted = await apply();

          expect(
            conflicted,
            ExitCodes.attention,
            reason: project.logger.output,
          );
          expect(
            projectConfig(await open(), 'Release-dev').buildSettings,
            containsPair('MY_SETTING', 'one'),
            reason: 'nothing is written while there is a conflict',
          );

          final code = await apply(['--on-conflict', 'overwrite']);

          expect(code, ExitCodes.ok, reason: project.logger.output);

          final xcodeproj = await open();

          expect(
            projectConfig(xcodeproj, 'Debug-dev').buildSettings['MY_SETTING'],
            'mine',
          );
          expect(
            projectConfig(xcodeproj, 'Release-dev').buildSettings,
            isNot(contains('MY_SETTING')),
          );
          expect(
            (await locked()).keys[_iosPbxproj]!.keys,
            isNot(contains(await keyOf('project', 'Debug-dev', 'MY_SETTING'))),
            reason: 'flavorizr does not own it anymore',
          );
        },
      );

      test('and the settings of a flavor that was dropped go with its '
          'configurations, the rest stays', () async {
        project.write(
          'flavorizr.yaml',
          _config(['dev', 'prod'], ios: _settings({'MY_SETTING': 'one'})),
        );
        await apply();

        final dropped = {
          for (final name in ['Debug-prod', 'Profile-prod', 'Release-prod'])
            projectConfig(await open(), name).uuid,
          for (final name in ['Debug-prod', 'Profile-prod', 'Release-prod'])
            targetConfig(await open(), name).uuid,
        };

        project.write(
          'flavorizr.yaml',
          _config(['dev'], ios: _settings({'MY_SETTING': 'one'})),
        );
        final code = await apply();

        expect(code, ExitCodes.ok, reason: project.logger.output);

        final xcodeproj = await open();

        expect(
          xcodeproj.buildConfigurationList.buildConfigurations.map(
            (c) => c.name,
          ),
          isNot(contains(contains('prod'))),
        );
        expect(
          xcodeproj
              .nativeTargets
              .first
              .buildConfigurationList!
              .buildConfigurations
              .map((c) => c.name),
          isNot(contains(contains('prod'))),
        );
        expect(
          projectConfig(xcodeproj, 'Debug-dev').buildSettings['MY_SETTING'],
          'one',
        );
        expect(
          (await locked()).keys[_iosPbxproj]!.keys.map((k) => k.split('/')[1]),
          everyElement(isNot(isIn(dropped))),
        );
        expect(danglingUuids(project.read(_iosPbxproj)), isEmpty);
      });

      test('but a configuration that holds a setting of the user stays, with '
          'that setting, and is not flavorizr\'s anymore', () async {
        project.write('flavorizr.yaml', _config(['dev', 'prod']));
        await apply();
        await edit((xcodeproj) {
          targetConfig(xcodeproj, 'Debug-prod').buildSettings = {
            ...targetConfig(xcodeproj, 'Debug-prod').buildSettings,
            'DEVELOPMENT_TEAM': 'ABCDE12345',
          };
          projectConfig(xcodeproj, 'Release-prod').buildSettings = {
            ...projectConfig(xcodeproj, 'Release-prod').buildSettings,
            'DEVELOPMENT_TEAM': 'FGHIJ67890',
          };
        });
        final kept = {
          targetConfig(await open(), 'Debug-prod').uuid,
          projectConfig(await open(), 'Release-prod').uuid,
        };

        project.write('flavorizr.yaml', _config(['dev']));
        // What the user added to a configuration of the project is part of what
        // the lock hashes, so the run asks about the project first.
        final code = await apply(['--on-conflict', 'overwrite']);

        expect(code, ExitCodes.ok, reason: project.logger.output);

        final xcodeproj = await open();

        expect(targetConfig(xcodeproj, 'Debug-prod').buildSettings, {
          'DEVELOPMENT_TEAM': 'ABCDE12345',
        });
        expect(
          projectConfig(xcodeproj, 'Release-prod').buildSettings,
          containsPair('DEVELOPMENT_TEAM', 'FGHIJ67890'),
        );
        expect(
          xcodeproj.buildConfigurationList.buildConfigurations.map(
            (c) => c.name,
          ),
          allOf(
            contains('Release-prod'),
            isNot(contains('Debug-prod')),
            isNot(contains('Profile-prod')),
          ),
        );
        expect(
          xcodeproj
              .nativeTargets
              .first
              .buildConfigurationList!
              .buildConfigurations
              .map((c) => c.name),
          allOf(
            contains('Debug-prod'),
            isNot(contains('Release-prod')),
            isNot(contains('Profile-prod')),
          ),
        );
        expect(
          (await locked()).objects[_iosPbxproj]!.intersection(kept),
          isEmpty,
          reason: 'the user has them now',
        );
        expect(danglingUuids(project.read(_iosPbxproj)), isEmpty);

        // And they stay on the next run.
        expect(await apply(), ExitCodes.ok, reason: project.logger.output);
        expect(
          targetConfig(await open(), 'Debug-prod').buildSettings,
          containsPair('DEVELOPMENT_TEAM', 'ABCDE12345'),
        );
      });
    });

    group('a setting flavorizr wrote that is edited by hand', () {
      Future<void> editSwiftVersion() => edit((xcodeproj) {
        projectConfig(xcodeproj, 'Debug-dev').buildSettings = {
          ...projectConfig(xcodeproj, 'Debug-dev').buildSettings,
          'SWIFT_VERSION': '6.0',
        };
      });

      test('is a conflict, and is kept', () async {
        await apply();
        await editSwiftVersion();
        final edited = project.read(_iosPbxproj);

        final code = await apply();

        expect(code, ExitCodes.attention, reason: project.logger.output);
        expect(project.read(_iosPbxproj), edited);
        expect(
          projectConfig(
            await open(),
            'Debug-dev',
          ).buildSettings['SWIFT_VERSION'],
          '6.0',
        );
      });

      test('is written over when the user says so, and the other settings '
          'survive', () async {
        await apply();
        await editSwiftVersion();
        await edit((xcodeproj) {
          targetConfig(xcodeproj, 'Debug-dev').buildSettings = {
            ...targetConfig(xcodeproj, 'Debug-dev').buildSettings,
            'DEVELOPMENT_TEAM': 'ABCDE12345',
          };
        });

        final code = await apply(['--on-conflict', 'overwrite']);

        expect(code, ExitCodes.ok, reason: project.logger.output);

        final xcodeproj = await open();

        expect(
          projectConfig(xcodeproj, 'Debug-dev').buildSettings['SWIFT_VERSION'],
          '5.0',
        );
        expect(
          targetConfig(
            xcodeproj,
            'Debug-dev',
          ).buildSettings['DEVELOPMENT_TEAM'],
          'ABCDE12345',
        );
      });

      test(
        'is not a conflict for a setting that flavorizr does not own',
        () async {
          await apply();
          await edit((xcodeproj) {
            targetConfig(xcodeproj, 'Debug-dev').buildSettings = {
              ...targetConfig(xcodeproj, 'Debug-dev').buildSettings,
              'DEVELOPMENT_TEAM': 'ABCDE12345',
            };
          });
          project.write(
            'flavorizr.yaml',
            _config(['dev'], bundleId: 'it.example'),
          );

          final code = await apply();

          expect(code, ExitCodes.ok, reason: project.logger.output);
        },
      );
    });

    test('a run of ios:xcconfig alone does not hide a hand edit of a build '
        'setting from the next run of ios:buildTargets', () async {
      expect(
        await project.run([
          'apply',
          '--yes',
          'ios:xcconfig',
          'ios:buildTargets',
        ]),
        ExitCodes.ok,
        reason: project.logger.output,
      );
      await edit((xcodeproj) {
        projectConfig(xcodeproj, 'Debug-dev').buildSettings = {
          ...projectConfig(xcodeproj, 'Debug-dev').buildSettings,
          'SWIFT_VERSION': '6.0',
        };
      });

      expect(
        await project.run(['apply', '--yes', 'ios:xcconfig']),
        ExitCodes.ok,
        reason: project.logger.output,
      );

      final code = await apply();

      expect(code, ExitCodes.attention, reason: project.logger.output);
      expect(
        projectConfig(await open(), 'Debug-dev').buildSettings['SWIFT_VERSION'],
        '6.0',
      );
    });

    test('refuses a configuration with no iOS flavor left, instead of '
        'leaving what it owns behind', () async {
      await apply();
      final before = project.snapshot();

      project.write('flavorizr.yaml', '''
flavors:
  dev:
    app:
      name: Dev
    macos:
      bundleId: com.example.dev
''');
      before['flavorizr.yaml'] = project.read('flavorizr.yaml');

      final code = await apply();

      expect(code, ExitCodes.data, reason: project.logger.output);
      expect(project.snapshot(), before);
    });

    test('writes a flag setting the way the project stores it, and removes it '
        'when it leaves the yaml', () async {
      project.write(
        'flavorizr.yaml',
        _config(['dev'], ios: _settings({'OTHER_LDFLAGS': '-ObjC -all_load'})),
      );
      await apply();

      expect(
        projectConfig(await open(), 'Debug-dev').buildSettings['OTHER_LDFLAGS'],
        ['-ObjC', '-all_load'],
      );

      project.write('flavorizr.yaml', _config(['dev']));
      final code = await apply();

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(
        projectConfig(await open(), 'Debug-dev').buildSettings,
        isNot(contains('OTHER_LDFLAGS')),
      );
    });

    test('takes over the configurations that 2.x made, keeping their '
        'UUIDs and the settings they hold', () async {
      // The configurations exist already, with a random UUID.
      await edit((xcodeproj) {
        final list = xcodeproj.buildConfigurationList;
        final legacy = xcodeproj.newObject<XCBuildConfiguration>(
          (g, u) => XCBuildConfiguration(g, u),
        )..name = 'Debug-dev';

        legacy.buildSettings = {
          'SWIFT_VERSION': '4.2',
          'DEVELOPMENT_TEAM': 'ABCDE12345',
        };
        list.buildConfigurations.add(legacy);
      });
      final uuid = projectConfig(await open(), 'Debug-dev').uuid;

      final code = await apply();

      expect(code, ExitCodes.ok, reason: project.logger.output);

      final config = projectConfig(await open(), 'Debug-dev');

      expect(config.uuid, uuid);
      expect(config.buildSettings['SWIFT_VERSION'], '5.0');
      expect(config.buildSettings['DEVELOPMENT_TEAM'], 'ABCDE12345');
    });
  });

  group('macos:buildTargets', () {
    test('edits the settings key by key too', () async {
      final macos = CliFixture(android: false);

      addTearDown(macos.dispose);
      macos.write('flavorizr.yaml', '''
flavors:
  dev:
    app:
      name: Dev
    macos:
      bundleId: com.example.dev
''');
      macos.write(
        '$_macosProject/project.pbxproj',
        File(
          'test_resources/example_2x/macos/Runner.xcodeproj/project.pbxproj',
        ).readAsStringSync(),
      );

      expect(
        await macos.run(['apply', '--yes', 'macos:buildTargets']),
        ExitCodes.ok,
        reason: macos.logger.output,
      );

      final xcodeproj = await XcodeProject.open(macos.abs(_macosProject));

      xcodeproj
          .nativeTargets
          .first
          .buildConfigurationList!['Debug-dev']!
          .buildSettings = {
        'PRODUCT_NAME': r'$(TARGET_NAME)',
        'DEVELOPMENT_TEAM': 'ABCDE12345',
      };
      await xcodeproj.save();

      expect(
        await macos.run(['apply', '--yes', 'macos:buildTargets']),
        ExitCodes.ok,
        reason: macos.logger.output,
      );
      expect(
        (await XcodeProject.open(macos.abs(_macosProject)))
            .nativeTargets
            .first
            .buildConfigurationList!['Debug-dev']!
            .buildSettings['DEVELOPMENT_TEAM'],
        'ABCDE12345',
      );
      expect(
        (await locked(
          'macos:buildTargets',
          macos,
        )).keys['$_macosProject/project.pbxproj']!.keys,
        contains(
          OwnedBuildSettings.keyOf(
            'project',
            (await XcodeProject.open(
              macos.abs(_macosProject),
            )).buildConfigurationList['Debug-dev']!.uuid,
            'PRODUCT_BUNDLE_IDENTIFIER',
          ),
        ),
      );
    });
  });
}
