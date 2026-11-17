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
import 'package:flutter_flavorizr/src/engine/darwin/owned_objects.dart';
import 'package:flutter_flavorizr/src/engine/darwin/pbxproj_seed.dart';
import 'package:flutter_flavorizr/src/engine/flavorizr_context.dart';
import 'package:flutter_flavorizr/src/engine/resources/xcodeproj_resource.dart';
import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../entrypoint/cli_fixture.dart';
import 'pbxproj_integrity.dart';

const _pbxproj = XcodeprojResource.iosArtifact;

void main() {
  late Directory temp;
  late String bundle;
  late RecordingLogger logger;

  XCBuildConfiguration newConfig(XcodeProject project, String uuid) =>
      XCBuildConfiguration(project, uuid);

  /// A context of a processor that owned [previous] in the last run, over
  /// [project].
  FlavorizrContext contextOf(
    XcodeProject project, {
    Set<String> previous = const {},
  }) => FlavorizrContext(
    config: Flavorizr.parse(
      'flavors:\n  dev:\n    app:\n      name: dev\n'
      '    ios:\n      bundleId: com.example.dev\n',
    ),
    root: temp,
    projectRoot: temp,
    logger: logger,
    processorId: 'test:ios',
    previousObjects: {
      'test:ios': {_pbxproj.path: previous},
    },
    resources: {XcodeprojResource.iosKey: project},
  );

  Future<XcodeProject> open() => XcodeProject.open(bundle);

  String text() => File(p.join(bundle, 'project.pbxproj')).readAsStringSync();

  /// The `Debug-dev` configuration of the project, wired to the project.
  XCBuildConfiguration ensureProjectConfig(
    OwnedObjects owned,
    XcodeProject project, {
    int? created,
    void Function()? onCreate,
  }) => owned.ensure<XCBuildConfiguration>(
    newConfig,
    flavor: 'dev',
    kind: ['buildConfiguration', 'Debug'],
    create: (config) {
      onCreate?.call();
      config.name = 'Debug-dev';
      project.buildConfigurationList.buildConfigurations.add(config);
    },
  );

  setUp(() {
    temp = Directory.systemTemp.createTempSync('flavorizr_owned_');
    addTearDown(() => temp.deleteSync(recursive: true));
    logger = RecordingLogger();

    bundle = p.join(temp.path, 'ios', 'Runner.xcodeproj');
    Directory(bundle).createSync(recursive: true);
    File(
      'example/${_pbxproj.path}',
    ).copySync(p.join(bundle, 'project.pbxproj'));
  });

  group('OwnedObjects.ensure', () {
    test('creates the object with the UUID of its seed, and owns it', () async {
      final project = await open();
      final owned = OwnedObjects.ios(contextOf(project));

      final config = ensureProjectConfig(owned, project);

      final uuid = PbxprojSeed.uuid(
        platform: 'ios',
        flavor: 'dev',
        kind: ['buildConfiguration', 'Debug'],
      );
      expect(config.uuid, uuid);
      expect(project.objectsByUuid[uuid], same(config));
      expect(owned.owned, {uuid});
      expect(
        owned.uuidOf(flavor: 'dev', kind: ['buildConfiguration', 'Debug']),
        uuid,
      );
    });

    test('is idempotent inside a run: the same object, created once', () async {
      final project = await open();
      final owned = OwnedObjects.ios(contextOf(project));
      var created = 0;

      final first = ensureProjectConfig(
        owned,
        project,
        onCreate: () => created++,
      );
      final second = ensureProjectConfig(
        owned,
        project,
        onCreate: () => created++,
      );

      expect(second, same(first));
      expect(created, 1);
      expect(
        project.buildConfigurations.where((c) => c.name == 'Debug-dev'),
        hasLength(1),
      );
    });

    test('is idempotent across runs: it finds its object again and the file '
        'is byte identical', () async {
      final first = await open();
      final owned = OwnedObjects.ios(contextOf(first));
      ensureProjectConfig(owned, first);
      owned.settle();
      await first.save();
      final saved = text();

      final second = await open();
      var created = 0;
      final again = OwnedObjects.ios(contextOf(second, previous: owned.owned));
      final config = ensureProjectConfig(
        again,
        second,
        onCreate: () => created++,
      );
      again.settle();
      await second.save();

      expect(created, 0);
      expect(config.uuid, owned.owned.single);
      expect(again.owned, owned.owned);
      expect(text(), saved);
    });

    test('finds its object again when the lock was lost', () async {
      final first = await open();
      final owned = OwnedObjects.ios(contextOf(first));
      ensureProjectConfig(owned, first);
      await first.save();

      final second = await open();
      var created = 0;
      final again = OwnedObjects.ios(contextOf(second));
      ensureProjectConfig(again, second, onCreate: () => created++);

      expect(created, 0);
      expect(again.owned, owned.owned);
    });

    test('reuses a foreign object found by identity, never re-keys it and '
        'does not own it', () async {
      final project = await open();
      final foreign = project.newObject<XCBuildConfiguration>(
        (g, u) => XCBuildConfiguration(g, u),
        uuid: 'ABCDEF0123456789ABCDEF01',
      )..name = 'Debug-dev';
      project.buildConfigurationList.buildConfigurations.add(foreign);
      final owned = OwnedObjects.ios(contextOf(project));
      var created = 0;

      final config = owned.ensure<XCBuildConfiguration>(
        newConfig,
        flavor: 'dev',
        kind: ['buildConfiguration', 'Debug'],
        existing: () => project.buildConfigurationList['Debug-dev'],
        create: (_) => created++,
      );

      expect(config, same(foreign));
      expect(config.uuid, 'ABCDEF0123456789ABCDEF01');
      expect(created, 0);
      expect(owned.owned, isEmpty);
      expect(
        project.objectsByUuid.containsKey(
          owned.uuidOf(flavor: 'dev', kind: ['buildConfiguration', 'Debug']),
        ),
        isFalse,
      );
    });

    test('owns a foreign object when it is told to, with the UUID it has, and '
        'removes it like any other', () async {
      final first = await open();
      final foreign = first.newObject<XCBuildConfiguration>(
        (g, u) => XCBuildConfiguration(g, u),
        uuid: 'ABCDEF0123456789ABCDEF01',
      )..name = 'Debug-dev';
      first.buildConfigurationList.buildConfigurations.add(foreign);
      await first.save();
      final baseline = objectUuids(text()).difference({foreign.uuid});

      XCBuildConfiguration claim(OwnedObjects owned, XcodeProject project) =>
          owned.ensure<XCBuildConfiguration>(
            newConfig,
            flavor: 'dev',
            kind: ['buildConfiguration', 'Debug'],
            existing: () => project.buildConfigurationList['Debug-dev'],
            claimExisting: true,
            create: (_) => fail('it exists'),
          );

      final second = await open();
      final owned = OwnedObjects.ios(contextOf(second));
      final config = claim(owned, second);
      owned.settle();

      expect(config.uuid, 'ABCDEF0123456789ABCDEF01');
      expect(owned.owned, {'ABCDEF0123456789ABCDEF01'});

      final third = await open();
      final dropped = OwnedObjects.ios(contextOf(third, previous: owned.owned));

      expect(dropped.settle(), ['ABCDEF0123456789ABCDEF01']);
      await third.save();
      expect(objectUuids(text()), baseline);
      expect(danglingUuids(text()), isEmpty);
    });

    test('refuses a UUID that a different kind of object holds', () async {
      final project = await open();
      final uuid = PbxprojSeed.uuid(
        platform: 'ios',
        flavor: 'dev',
        kind: ['buildConfiguration', 'Debug'],
      );
      final squatter = project.newObject<PBXGroup>(
        (g, u) => PBXGroup(g, u),
        uuid: uuid,
      )..name = 'squatter';
      project.mainGroup.children.add(squatter);
      final owned = OwnedObjects.ios(contextOf(project));

      expect(
        () => ensureProjectConfig(owned, project),
        throwsA(
          isA<StateError>().having((e) => e.message, 'message', contains(uuid)),
        ),
      );
      expect(project.objectsByUuid[uuid], same(squatter));
      expect(owned.owned, isEmpty);
    });

    test('refuses an object that its create callback did not wire', () async {
      final project = await open();
      final owned = OwnedObjects.ios(contextOf(project));

      expect(
        () => owned.ensure<XCBuildConfiguration>(
          newConfig,
          flavor: 'dev',
          kind: ['buildConfiguration', 'Debug'],
          create: (config) => config.name = 'Debug-dev',
        ),
        throwsStateError,
      );
      expect(owned.owned, isEmpty);
    });

    test(
      'an object owned in the same run is not found twice by two kinds',
      () async {
        final project = await open();
        final owned = OwnedObjects.ios(contextOf(project));

        final debug = ensureProjectConfig(owned, project);
        final release = owned.ensure<XCBuildConfiguration>(
          newConfig,
          flavor: 'dev',
          kind: ['buildConfiguration', 'Release'],
          create: (config) {
            config.name = 'Release-dev';
            project.buildConfigurationList.buildConfigurations.add(config);
          },
        );

        expect(release.uuid, isNot(debug.uuid));
        expect(owned.owned, {debug.uuid, release.uuid});
      },
    );
  });

  group('OwnedObjects.settle', () {
    test('removes what the lock recorded and the run does not want anymore, '
        'with no dangling reference', () async {
      final baseline = objectUuids(text());
      final first = await open();
      final owned = OwnedObjects.ios(contextOf(first));
      final fileRef = owned.ensure<PBXFileReference>(
        (g, u) => PBXFileReference(g, u),
        flavor: 'dev',
        kind: ['fileReference', 'Debug'],
        create: (ref) {
          ref.path = 'dev.xcconfig';
          ref.sourceTree = '<group>';
          first.mainGroup.children.add(ref);
        },
      );
      final buildFile = owned.ensure<PBXBuildFile>(
        (g, u) => PBXBuildFile(g, u),
        flavor: 'dev',
        kind: ['buildFile', 'Debug'],
        create: (file) {
          file.fileRef = fileRef;
          (first.targets.first as PBXNativeTarget).resourcesBuildPhase.files
              .add(file);
        },
      );
      final config = ensureProjectConfig(owned, first);
      config.baseConfigurationReference = fileRef;
      owned.settle();
      await first.save();
      expect(owned.owned, {fileRef.uuid, buildFile.uuid, config.uuid});
      expect(text(), contains('dev.xcconfig'));
      expect(danglingUuids(text()), isEmpty);

      final second = await open();
      final nothing = OwnedObjects.ios(
        contextOf(second, previous: owned.owned),
      );
      final removed = nothing.settle();
      await second.save();

      expect(removed, unorderedEquals(owned.owned));
      expect(text(), isNot(contains('dev.xcconfig')));
      expect(text(), isNot(contains('Debug-dev')));
      for (final uuid in owned.owned) {
        expect(text(), isNot(contains(uuid)));
      }
      expect(danglingUuids(text()), isEmpty);
      expect(objectUuids(text()), baseline);
      expect(nothing.owned, isEmpty);
    });

    test('keeps what is still wanted, and removes only the rest', () async {
      final first = await open();
      final owned = OwnedObjects.ios(contextOf(first));
      final dev = ensureProjectConfig(owned, first);
      final prod = owned.ensure<XCBuildConfiguration>(
        newConfig,
        flavor: 'prod',
        kind: ['buildConfiguration', 'Debug'],
        create: (config) {
          config.name = 'Debug-prod';
          first.buildConfigurationList.buildConfigurations.add(config);
        },
      );
      await first.save();

      final second = await open();
      final again = OwnedObjects.ios(
        contextOf(second, previous: {dev.uuid, prod.uuid}),
      );
      ensureProjectConfig(again, second);
      final removed = again.settle();
      await second.save();

      expect(removed, [prod.uuid]);
      expect(second.objectsByUuid.containsKey(dev.uuid), isTrue);
      expect(text(), contains('Debug-dev'));
      expect(text(), isNot(contains('Debug-prod')));
      expect(danglingUuids(text()), isEmpty);
    });

    test('never touches an object that is not in the lock', () async {
      final baseline = objectUuids(text());
      final project = await open();
      final owned = OwnedObjects.ios(contextOf(project));

      owned.settle();
      await project.save();

      expect(objectUuids(text()), baseline);
    });

    test('forgets a UUID whose object is already gone', () async {
      final project = await open();
      final owned = OwnedObjects.ios(
        contextOf(project, previous: {'AAAAAAAAAAAAAAAAAAAAAAAA'}),
      );

      expect(owned.settle(), isEmpty);
      expect(owned.owned, isEmpty);
    });

    test('refuses to remove the project or its main group, whatever the lock '
        'says', () async {
      final project = await open();
      final root = project.rootObject.uuid;
      final main = project.mainGroup.uuid;
      final owned = OwnedObjects.ios(
        contextOf(project, previous: {root, main}),
      );

      expect(owned.settle(), isEmpty);
      expect(project.objectsByUuid.containsKey(root), isTrue);
      expect(project.objectsByUuid.containsKey(main), isTrue);
      expect(logger.warnings, hasLength(2));
    });

    test('refuses to remove a target either, whatever the lock says', () async {
      final project = await open();
      final target = project.targets.first.uuid;
      final owned = OwnedObjects.ios(contextOf(project, previous: {target}));

      expect(owned.settle(), isEmpty);
      expect(project.objectsByUuid.containsKey(target), isTrue);
      expect(logger.warnings, hasLength(1));
    });

    test('tells the context what the processor owns, even nothing', () async {
      final project = await open();
      final ctx = contextOf(project, previous: {'AAAAAAAAAAAAAAAAAAAAAAAA'});

      OwnedObjects.ios(ctx).settle();

      expect(ctx.ownedObjects, {
        'test:ios': {_pbxproj.path: <String>{}},
      });
    });

    test(
      'removes in the order of the UUIDs, whatever the order of the lock',
      () async {
        final project = await open();
        final refs = [
          for (final name in ['b', 'a', 'c'])
            project.newObject<PBXFileReference>(
                (g, u) => PBXFileReference(g, u),
              )
              ..path = '$name.txt'
              ..sourceTree = '<group>',
        ];
        for (final ref in refs) {
          project.mainGroup.children.add(ref);
        }
        final owned = OwnedObjects.ios(
          contextOf(project, previous: {for (final ref in refs) ref.uuid}),
        );

        expect(owned.settle(), [
          for (final ref in refs.map((r) => r.uuid).toList()..sort()) ref,
        ]);
      },
    );
  });
}
