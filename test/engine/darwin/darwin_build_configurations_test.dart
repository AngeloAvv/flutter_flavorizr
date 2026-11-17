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
import 'package:flutter_flavorizr/src/engine/darwin/darwin_build_configurations.dart';
import 'package:flutter_flavorizr/src/engine/darwin/owned_objects.dart';
import 'package:flutter_flavorizr/src/engine/darwin/pbxproj_seed.dart';
import 'package:flutter_flavorizr/src/engine/flavorizr_context.dart';
import 'package:flutter_flavorizr/src/engine/flavorizr_processor.dart';
import 'package:flutter_flavorizr/src/engine/lock/lock_codec.dart';
import 'package:flutter_flavorizr/src/engine/resource_key.dart';
import 'package:flutter_flavorizr/src/engine/resources/xcodeproj_resource.dart';
import 'package:flutter_flavorizr/src/entrypoint/cli_context.dart';
import 'package:flutter_flavorizr/src/entrypoint/exit_codes.dart';
import 'package:flutter_flavorizr/src/entrypoint/processor_registry.dart';
import 'package:flutter_flavorizr/src/entrypoint/run.dart' as cli;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../entrypoint/cli_fixture.dart';
import 'pbxproj_integrity.dart';
import 'pristine_project.dart';

const _pbxprojPath = 'ios/Runner.xcodeproj/project.pbxproj';
const _processorId = 'test:ios';

/// What `ios:buildTargets` and the project half of `ios:xcconfig` do to the
/// project, built on the building blocks of the Darwin processors to come: the
/// shared resource, `OwnedObjects` and `DarwinBuildConfigurations`.
class _BuildTargetsProcessor extends FlavorizrProcessor {
  /// The flavors that are wanted, with the settings of each.
  final Map<String, Map<String, dynamic>> Function() wanted;

  /// Where the xcconfig files are, and whether the objects that exist are
  /// owned.
  final String Function() xcconfigDir;
  final bool Function() claim;

  const _BuildTargetsProcessor(this.wanted, this.xcconfigDir, this.claim);

  @override
  String get id => _processorId;

  @override
  Set<ResourceKey<Object?>> get requires => {XcodeprojResource.iosKey};

  @override
  Future<void> apply(FlavorizrContext ctx) async {
    final owned = OwnedObjects.ios(ctx);

    for (final MapEntry(key: flavor, value: settings) in wanted().entries) {
      DarwinBuildConfigurations.ensure(
        owned,
        flavor: flavor,
        buildSettings: settings,
        xcconfigPath: (mode) => '${xcconfigDir()}/$flavor$mode.xcconfig',
        claimExisting: claim(),
      );
    }

    owned.settle();
    ctx.track(XcodeprojResource.iosArtifact);
  }
}

void main() {
  late List<CliFixture> fixtures;
  late Map<String, Map<String, dynamic>> wanted;
  late String pristine;
  late String xcconfigDir;
  late bool claim;

  Future<int> run(CliFixture project, {String command = 'apply'}) {
    final context = CliContext(
      projectRoot: project.root,
      logger: project.logger,
      terminal: NoTerminal(),
      legacy: project.legacy,
      version: '3.0.0',
      registry: ProcessorRegistry(
        engine: [
          EngineProcessor(
            _BuildTargetsProcessor(
              () => wanted,
              () => xcconfigDir,
              () => claim,
            ),
            paths: const {},
          ),
        ],
        resources: [
          EngineResource(
            XcodeprojResource.ios(),
            paths: const {XcodeprojResource.iosProject},
          ),
        ],
      ),
    );

    return cli.run([command, '--yes', _processorId], context: context);
  }

  CliFixture newProject() {
    final project = CliFixture(android: false)..write(_pbxprojPath, pristine);
    fixtures.add(project);

    return project;
  }

  Future<int> apply(CliFixture project) => run(project);

  Set<String> lockedObjects(CliFixture project) {
    final lock = LockCodec.decode(
      project.read('flavorizr.lock'),
      runningVersion: '3.0.0',
    );

    return lock.processors[_processorId]?.objects[_pbxprojPath] ?? {};
  }

  String uuidOf(
    String flavor,
    String mode, {
    String? target,
    String kind = 'buildConfiguration',
  }) => PbxprojSeed.uuid(
    platform: 'ios',
    target: target,
    flavor: flavor,
    kind: [
      if (kind == 'buildFile') ...['buildFile', 'resources'] else kind,
      mode,
    ],
  );

  setUpAll(() async {
    final temp = Directory.systemTemp.createTempSync('flavorizr_pristine_');
    addTearDown(() => temp.deleteSync(recursive: true));

    pristine = await pristineIosPbxproj(temp);
  });

  setUp(() {
    fixtures = [];
    xcconfigDir = 'Flutter';
    claim = false;
    wanted = {
      'apple': {'FLAVOR': 'apple'},
      'banana': {'FLAVOR': 'banana'},
    };
  });
  tearDown(() {
    for (final fixture in fixtures) {
      fixture.dispose();
    }
  });

  group('the objects flavorizr creates in an Xcode project', () {
    test(
      'are created with the UUIDs of their seeds and recorded in the lock',
      () async {
        final project = newProject();

        final code = await apply(project);

        expect(code, ExitCodes.ok, reason: project.logger.output);
        // 3 modes, each with 2 configurations, a file reference and a build file.
        expect(lockedObjects(project), hasLength(2 * 3 * 4));
        expect(
          lockedObjects(project),
          containsAll([
            uuidOf('apple', 'Debug'),
            uuidOf('apple', 'Debug', target: 'Runner'),
            uuidOf('banana', 'Release', kind: 'fileReference'),
            uuidOf('banana', 'Profile', target: 'Runner', kind: 'buildFile'),
          ]),
        );
        expect(
          objectUuids(project.read(_pbxprojPath)),
          containsAll(lockedObjects(project)),
        );
        for (final uuid in lockedObjects(project)) {
          expect(uuid, hasLength(24));
        }
      },
    );

    test('make two applies from scratch write the very same project and '
        'lock', () async {
      final first = newProject();
      final second = newProject();

      expect(await apply(first), ExitCodes.ok);
      expect(await apply(second), ExitCodes.ok);

      expect(first.read(_pbxprojPath), second.read(_pbxprojPath));
      expect(first.read('flavorizr.lock'), second.read('flavorizr.lock'));
      expect(first.read(_pbxprojPath), isNot(pristine));
    });

    test('leave the project byte identical on a second apply', () async {
      final project = newProject();
      await apply(project);
      final file = File(p.join(project.root.path, _pbxprojPath));
      final bytes = file.readAsBytesSync();
      final lock = project.read('flavorizr.lock');

      final code = await apply(project);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(file.readAsBytesSync(), bytes);
      expect(project.read('flavorizr.lock'), lock);
    });

    test('are found again when the lock was lost, without a diff', () async {
      final project = newProject();
      await apply(project);
      final written = project.read(_pbxprojPath);
      final locked = lockedObjects(project);
      File(p.join(project.root.path, 'flavorizr.lock')).deleteSync();

      final code = await apply(project);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.read(_pbxprojPath), written);
      expect(lockedObjects(project), locked);
    });

    test('leave a project that opens, whose references all resolve and whose '
        'other objects keep their UUIDs', () async {
      final baseline = objectUuids(pristine);
      final project = newProject();

      await apply(project);

      final text = project.read(_pbxprojPath);
      expect(danglingUuids(text), isEmpty);
      expect(objectUuids(text).containsAll(baseline), isTrue);
      expect(
        objectUuids(text).difference(baseline),
        lockedObjects(project),
        reason: 'what flavorizr added is exactly what the lock records',
      );

      final opened = await XcodeProject.open(
        p.join(project.root.path, XcodeprojResource.iosProject),
      );
      final target = opened.targets.first as PBXNativeTarget;
      for (final flavor in wanted.keys) {
        for (final mode in DarwinBuildConfigurations.modes) {
          final config = opened.buildConfigurationList['$mode-$flavor']!;
          expect(config.uuid, uuidOf(flavor, mode));
          expect(config.buildSettings['FLAVOR'], flavor);
          expect(
            config.baseConfigurationReference?.path,
            'Flutter/$flavor$mode.xcconfig',
          );
          expect(
            target.buildConfigurationList!['$mode-$flavor']!.uuid,
            uuidOf(flavor, mode, target: 'Runner'),
          );
        }
      }
    });

    test('are removed with their flavor, and what is left is the project as '
        'if the flavor had never been', () async {
      final both = newProject();
      final onlyApple = newProject();
      wanted = {'apple': wanted['apple']!};
      await apply(onlyApple);
      wanted = {
        'apple': wanted['apple']!,
        'banana': {'FLAVOR': 'banana'},
      };
      await apply(both);
      final before = lockedObjects(both);
      wanted = {'apple': wanted['apple']!};

      final code = await apply(both);

      expect(code, ExitCodes.ok, reason: both.logger.output);
      final text = both.read(_pbxprojPath);
      expect(danglingUuids(text), isEmpty);
      expect(text, isNot(contains('banana')));
      expect(lockedObjects(both), hasLength(before.length ~/ 2));
      expect(before.containsAll(lockedObjects(both)), isTrue);
      for (final uuid in before.difference(lockedObjects(both))) {
        expect(text, isNot(contains(uuid)));
      }
      expect(text, onlyApple.read(_pbxprojPath));
      expect(both.read('flavorizr.lock'), onlyApple.read('flavorizr.lock'));
    });

    test('are all removed with the last flavor: the project is the one '
        'flavorizr found', () async {
      final project = newProject();
      await apply(project);
      wanted = {};

      final code = await apply(project);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.read(_pbxprojPath), pristine);
      expect(project.read('flavorizr.lock'), isNot(contains('objects')));
    });

    test('are not made again over a configuration that exists: it is used as '
        'it is, keeps its UUID, and is never removed', () async {
      final project = newProject();
      const foreign = 'ABCDEF0123456789ABCDEF01';
      final source = await XcodeProject.open(
        p.join(project.root.path, XcodeprojResource.iosProject),
      );
      source.buildConfigurationList.buildConfigurations.add(
        source.newObject<XCBuildConfiguration>(
            (g, u) => XCBuildConfiguration(g, u),
            uuid: foreign,
          )
          ..name = 'Debug-apple'
          ..buildSettings = {'MINE': 'yes'},
      );
      await source.save();
      wanted = {'apple': wanted['apple']!};

      expect(await apply(project), ExitCodes.ok, reason: project.logger.output);

      var text = project.read(_pbxprojPath);
      expect(text, contains(foreign));
      expect(text, contains('MINE = yes'));
      // The foreign one of the project, and the one of the target that is new.
      expect(RegExp(r'name = "?Debug-apple"?;').allMatches(text), hasLength(2));
      expect(lockedObjects(project), isNot(contains(foreign)));
      expect(lockedObjects(project), isNot(contains(uuidOf('apple', 'Debug'))));
      expect(
        lockedObjects(project),
        contains(uuidOf('apple', 'Debug', target: 'Runner')),
      );
      expect(lockedObjects(project), contains(uuidOf('apple', 'Release')));

      wanted = {};
      expect(await apply(project), ExitCodes.ok, reason: project.logger.output);

      text = project.read(_pbxprojPath);
      expect(text, contains(foreign));
      expect(text, isNot(contains('Release-apple')));
      expect(danglingUuids(text), isEmpty);
    });

    test(
      'are not recorded when the project they were created in is not '
      'written: a conflict the user keeps leaves the lock as it was',
      () async {
        wanted = {'apple': wanted['apple']!};
        final project = newProject();
        await apply(project);
        final recorded = lockedObjects(project);
        // Xcode edits the project: with the whole file hashed, a conflict.
        project.write(
          _pbxprojPath,
          project
              .read(_pbxprojPath)
              .replaceFirst(
                'LastUpgradeCheck = 1510;',
                'LastUpgradeCheck = 1600;',
              ),
        );
        final edited = project.read(_pbxprojPath);
        wanted = {
          'apple': {'FLAVOR': 'apple'},
          'banana': {'FLAVOR': 'banana'},
        };

        final code = await apply(project);

        expect(code, ExitCodes.attention, reason: project.logger.output);
        expect(project.read(_pbxprojPath), edited);
        expect(lockedObjects(project), recorded);
      },
    );

    test('follow their xcconfig file when it moves', () async {
      wanted = {'apple': wanted['apple']!};
      final project = newProject();
      await apply(project);
      final recorded = lockedObjects(project);
      xcconfigDir = 'Flutter/flavors';

      final code = await apply(project);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      final text = project.read(_pbxprojPath);
      expect(text, contains('path = Flutter/flavors/appleDebug.xcconfig;'));
      expect(text, isNot(contains('path = Flutter/appleDebug.xcconfig;')));
      expect(lockedObjects(project), recorded);
    });

    test('are all owned, the ones 2.x made too, when the processor claims '
        'them, so that dropping the flavors removes them', () async {
      final source = File('example/$_pbxprojPath').readAsStringSync();
      final project = CliFixture(android: false)..write(_pbxprojPath, source);
      fixtures.add(project);
      claim = true;

      expect(await apply(project), ExitCodes.ok, reason: project.logger.output);

      final text = project.read(_pbxprojPath);
      // 2.x made 3 configurations in the project, 3 file references and 3 build
      // files for each flavor, flavorizr 3 in the target: all of them are owned.
      expect(lockedObjects(project), hasLength(2 * 3 * 4));
      expect(
        objectUuids(text),
        objectUuids(source).union(lockedObjects(project)),
      );
      for (final foreign in [
        '4CB6B4B04B741184823C1765',
        'F2FCBFD0B17331A657473E5C',
      ]) {
        expect(lockedObjects(project), contains(foreign));
      }

      wanted = {};
      expect(await apply(project), ExitCodes.ok, reason: project.logger.output);

      final after = project.read(_pbxprojPath);
      expect(danglingUuids(after), isEmpty);
      expect(
        RegExp(
          r'(apple|banana)(Debug|Profile|Release)\.xcconfig',
        ).hasMatch(after),
        isFalse,
      );
      expect(RegExp(r'-(apple|banana)').hasMatch(after), isFalse);
      // The launch screens 2.x made too are not the business of this processor.
      expect(after, contains('appleLaunchScreen.storyboard'));
    });

    test('only add what a project 2.x flavorized lacks, and use the rest as it '
        'is: it keeps its UUIDs and is not owned', () async {
      final source = File('example/$_pbxprojPath').readAsStringSync();
      final project = CliFixture(android: false)..write(_pbxprojPath, source);
      fixtures.add(project);

      final code = await apply(project);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      final text = project.read(_pbxprojPath);
      // The example has the configurations of 2.x in the project, but none in
      // the target: they are the only thing flavorizr owns.
      expect(lockedObjects(project), {
        for (final flavor in wanted.keys)
          for (final mode in DarwinBuildConfigurations.modes)
            uuidOf(flavor, mode, target: 'Runner'),
      });
      expect(objectUuids(text).containsAll(objectUuids(source)), isTrue);
      expect(
        objectUuids(text).difference(objectUuids(source)),
        lockedObjects(project),
      );
      expect(danglingUuids(text), isEmpty);

      wanted = {};
      expect(await apply(project), ExitCodes.ok, reason: project.logger.output);
      expect(project.read(_pbxprojPath), source);
    });
  });
}
