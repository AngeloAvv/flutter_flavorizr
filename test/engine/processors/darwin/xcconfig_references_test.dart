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
import 'package:flutter_flavorizr/src/engine/processors/darwin/xcconfig_references.dart';
import 'package:flutter_flavorizr/src/engine/resources/xcodeproj_resource.dart';
import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../entrypoint/cli_fixture.dart';

const _ios = 'example/ios/Runner.xcodeproj';
const _macos = 'example/macos/Runner.xcodeproj';

/// Every build file of every build phase of the project.
Iterable<PBXBuildFile> _buildFiles(XcodeProject project) => project.targets
    .whereType<PBXNativeTarget>()
    .expand((target) => target.buildPhases)
    .expand((phase) => phase.files);

/// The xcconfig files that the Resources phases of the project hold.
List<String> _xcconfigResources(XcodeProject project) => [
  for (final target in project.targets.whereType<PBXNativeTarget>())
    for (final phase in target.buildPhases.whereType<PBXResourcesBuildPhase>())
      for (final file in phase.files.map((file) => file.fileRef))
        if (file is PBXFileReference && file.path!.endsWith('.xcconfig'))
          file.path!,
];

/// The context of `ios:xcconfig`, which owned [previous] in the last run, over
/// [project].
FlavorizrContext _context(
  XcodeProject project, {
  Set<String> previous = const {},
  bool macos = false,
}) {
  final artifact = macos
      ? XcodeprojResource.macosArtifact
      : XcodeprojResource.iosArtifact;

  return FlavorizrContext(
    config: FlavorizrConfig.parse(
      'flavors:\n  dev:\n    app:\n      name: dev\n'
      '    ios:\n      bundleId: com.example.dev\n',
    ),
    root: Directory.systemTemp,
    projectRoot: Directory.systemTemp,
    logger: RecordingLogger(),
    processorId: 'test:xcconfig',
    previousObjects: {
      'test:xcconfig': {artifact.path: previous},
    },
    resources: {
      macos ? XcodeprojResource.macosKey : XcodeprojResource.iosKey: project,
    },
  );
}

OwnedObjects _owned(
  XcodeProject project, {
  Set<String> previous = const {},
  bool macos = false,
}) {
  final ctx = _context(project, previous: previous, macos: macos);

  return macos ? OwnedObjects.macos(ctx) : OwnedObjects.ios(ctx);
}

String _uuidOf(String path, {String platform = 'ios'}) => PbxprojSeed.uuid(
  platform: platform,
  kind: ['xcconfigFileReference', ...path.split('/')],
);

void main() {
  group('the reference to a flavor xcconfig', () {
    late XcodeProject project;

    setUp(() async => project = await XcodeProject.open(_ios));

    PBXFileReference ensure(
      String path, {
      String? groupName = 'Flutter',
      OwnedObjects? owned,
    }) => ensureXcconfigReference(
      owned ?? _owned(project),
      path,
      groupName: groupName,
    );

    PBXGroup flutterGroup() =>
        project.groups.firstWhere((group) => group.name == 'Flutter');

    test('is a text xcconfig in the group it is asked for', () {
      final reference = ensure('Flutter/citrusDebug.xcconfig');

      expect(reference.path, 'Flutter/citrusDebug.xcconfig');
      expect(reference.sourceTree, '<group>');
      expect(reference.lastKnownFileType, 'text.xcconfig');
      expect(flutterGroup().children, contains(reference));
    });

    test('goes in the main group when no group is asked for', () {
      final reference = ensure(
        'Runner/Configs/citrusDebug.xcconfig',
        groupName: null,
      );

      expect(project.mainGroup.children, contains(reference));
    });

    test('has the UUID of its path, and is owned', () {
      final owned = _owned(project);

      final reference = ensure('Flutter/citrusDebug.xcconfig', owned: owned);

      expect(reference.uuid, _uuidOf('Flutter/citrusDebug.xcconfig'));
      expect(owned.owned, {reference.uuid});
    });

    test('is not in any build phase, Resources included', () {
      final before = _buildFiles(project).length;

      final reference = ensure('Flutter/citrusDebug.xcconfig');

      expect(_buildFiles(project).length, before);
      expect(
        _buildFiles(project).where((file) => file.fileRef == reference),
        isEmpty,
      );
    });

    test('is found again, not added twice', () {
      final first = ensure('Flutter/citrusDebug.xcconfig');
      final model = project.toHash();

      final second = ensure('Flutter/citrusDebug.xcconfig');

      expect(second, same(first));
      expect(project.toHash(), model);
    });

    test('is found again in the next run, by its UUID, with no lock', () async {
      final first = ensure('Flutter/citrusDebug.xcconfig');
      final model = project.toHash();
      final again = _owned(project);

      expect(ensure('Flutter/citrusDebug.xcconfig', owned: again), same(first));
      expect(again.owned, {first.uuid});
      expect(project.toHash(), model);
    });

    test('is not owned when the project had it, and is not duplicated: the '
        'lock tells whose it is', () {
      // `apple` was flavorized by 2.x.
      final owned = _owned(project);
      final existing = project.files.firstWhere(
        (file) => file.path == 'Flutter/appleDebug.xcconfig',
      );
      final model = project.toHash();

      final reference = ensure('Flutter/appleDebug.xcconfig', owned: owned);

      expect(reference, same(existing));
      expect(owned.owned, isEmpty);
      expect(owned.settle(), isEmpty);
      expect(project.toHash(), model);
    });

    test('is owned when the lock says the processor made it', () {
      final existing = project.files.firstWhere(
        (file) => file.path == 'Flutter/appleDebug.xcconfig',
      );
      final owned = _owned(project, previous: {existing.uuid});

      ensure('Flutter/appleDebug.xcconfig', owned: owned);

      expect(owned.owned, {existing.uuid});
    });

    test('gets the type a 2.x reference lacked', () {
      final existing = project.files.firstWhere(
        (file) => file.path == 'Flutter/appleDebug.xcconfig',
      );
      existing.lastKnownFileType = null;

      final again = ensure('Flutter/appleDebug.xcconfig');

      expect(again, same(existing));
      expect(again.lastKnownFileType, 'text.xcconfig');
    });

    test('is removed, with what points at it, when the next run does not want '
        'it', () async {
      final reference = ensure('Flutter/citrusDebug.xcconfig');
      final dates = ensure('Flutter/datesDebug.xcconfig');
      final next = _owned(project, previous: {reference.uuid, dates.uuid});

      ensure('Flutter/citrusDebug.xcconfig', owned: next);
      final removed = next.settle();

      expect(removed, [dates.uuid]);
      expect(project.objectsByUuid[dates.uuid], isNull);
      expect(flutterGroup().children, isNot(contains(dates)));
      expect(project.objectsByUuid[reference.uuid], same(reference));
    });

    test('is in the project of macOS as well', () async {
      final macos = await XcodeProject.open(_macos);

      final reference = ensureXcconfigReference(
        _owned(macos, macos: true),
        'Runner/Configs/citrusDebug.xcconfig',
      );

      expect(macos.mainGroup.children, contains(reference));
      expect(
        reference.uuid,
        _uuidOf('Runner/Configs/citrusDebug.xcconfig', platform: 'macos'),
      );
      expect(
        _xcconfigResources(macos),
        isNot(contains('Runner/Configs/citrusDebug.xcconfig')),
      );
    });

    test('fails with a message when a new one needs a group that does not '
        'exist', () {
      expect(
        () => ensure('Flutter/citrusDebug.xcconfig', groupName: 'Nope'),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('`Nope`'),
          ),
        ),
      );
    });
  });

  group('the xcconfigs of the flavors in the Resources phases', () {
    late XcodeProject project;

    setUp(() async => project = await XcodeProject.open(_ios));

    PBXNativeTarget target(String name) => project.targets
        .whereType<PBXNativeTarget>()
        .firstWhere((target) => target.name == name);

    PBXFileReference reference(String path, {PBXGroup? group}) {
      final file = project.newObject<PBXFileReference>(
        (g, u) => PBXFileReference(g, u),
      );

      file.path = path;
      file.sourceTree = '<group>';
      (group ?? project.mainGroup).children.add(file);

      return file;
    }

    PBXBuildFile resource(PBXNativeTarget target, PBXFileReference file) =>
        target.resourcesBuildPhase.addFileReference(file);

    test('are all taken out, whatever the flavor, and nothing else is', () {
      // The example was flavorized by 2.x, with `apple` and `banana`.
      final all = _buildFiles(project).length;
      expect(_xcconfigResources(project), hasLength(6));

      removeXcconfigsFromResources(project);

      expect(_xcconfigResources(project), isEmpty);
      expect(_buildFiles(project).length, all - 6);
    });

    test('are taken out of the project of macOS too', () async {
      final macos = await XcodeProject.open(_macos);
      expect(_xcconfigResources(macos), hasLength(6));

      removeXcconfigsFromResources(macos);

      expect(_xcconfigResources(macos), isEmpty);
    });

    test('are taken out of every target, and whatever the nesting of the '
        'reference', () {
      final nested = project.newObject<PBXGroup>((g, u) => PBXGroup(g, u));
      project.mainGroup.children.add(nested);
      resource(
        target('Runner'),
        reference('Flutter/zebraDebug.xcconfig', group: nested),
      );
      resource(
        target('RunnerTests'),
        reference('Runner/Configs/zebraRelease.xcconfig'),
      );

      removeXcconfigsFromResources(project);

      expect(_xcconfigResources(project), isEmpty);
    });

    test('are taken out as many times as they are listed, and by whichever '
        'reference they point at', () {
      final first = reference('Flutter/zebraDebug.xcconfig');
      final second = reference('Flutter/zebraDebug.xcconfig');
      resource(target('Runner'), first);
      resource(target('Runner'), first);
      resource(target('Runner'), second);
      expect(
        _xcconfigResources(project),
        contains('Flutter/zebraDebug.xcconfig'),
      );

      removeXcconfigsFromResources(project);

      expect(
        _xcconfigResources(project),
        isNot(contains('Flutter/zebraDebug.xcconfig')),
      );
    });

    test('keep a flavor that has capitals, and ignore what is not named like '
        'flavorizr names them', () {
      final kept = [
        'Flutter/Debug.xcconfig',
        'Flutter/Release.xcconfig',
        'Flutter/mine.xcconfig',
        'Flutter/zebradebug.xcconfig',
        'Flutter/ZebraDEBUG.xcconfig',
        'Flutter-Debug.xcconfig',
        'Debug.xcconfig',
        'Other/zebraDebug.xcconfig',
        'Pods/Target Support Files/Pods-Runner/Pods-Runner.debug.xcconfig',
        'Flutter/zebraDebug.plist',
      ];
      for (final path in kept) {
        resource(target('Runner'), reference(path));
      }
      resource(target('Runner'), reference('Flutter/MyZebraProfile.xcconfig'));

      removeXcconfigsFromResources(project);

      expect(
        _xcconfigResources(project),
        containsAll(kept.where((path) => path.endsWith('.xcconfig'))),
      );
      expect(
        _xcconfigResources(project),
        isNot(contains('Flutter/MyZebraProfile.xcconfig')),
      );
    });

    test('are left in the phases that are not Resources', () {
      final file = reference('Flutter/zebraDebug.xcconfig');
      final runner = target('Runner');
      final copy = runner.newCopyFilesBuildPhase('Copy');
      copy.addFileReference(file);
      runner.sourceBuildPhase.addFileReference(file);
      resource(runner, file);

      removeXcconfigsFromResources(project);

      expect(copy.buildFile(file), isNotNull);
      expect(runner.sourceBuildPhase.buildFile(file), isNotNull);
      expect(runner.resourcesBuildPhase.buildFile(file), isNull);
    });

    test('are taken out of the phases that share an entry, which the other '
        'phases keep whole', () {
      final file = reference('Flutter/zebraDebug.xcconfig');
      final runner = target('Runner');
      final entry = resource(runner, file);
      final copy = runner.newCopyFilesBuildPhase('Copy');
      copy.files.add(entry);
      target('RunnerTests').resourcesBuildPhase.files.add(entry);

      removeXcconfigsFromResources(project);

      expect(runner.resourcesBuildPhase.files, isNot(contains(entry)));
      expect(
        target('RunnerTests').resourcesBuildPhase.files,
        isNot(contains(entry)),
      );
      // Still listed by a phase that is not Resources: it is not broken.
      expect(copy.files, contains(entry));
      expect(entry.fileRef, file);
    });

    test(
      'are taken out of every Resources phase that lists the same entry',
      () {
        final entry = resource(
          target('Runner'),
          reference('Flutter/zebraDebug.xcconfig'),
        );
        target('RunnerTests').resourcesBuildPhase.files.add(entry);
        expect(target('Runner').resourcesBuildPhase.files, contains(entry));
        expect(
          target('RunnerTests').resourcesBuildPhase.files,
          contains(entry),
        );

        removeXcconfigsFromResources(project);

        expect(
          target('Runner').resourcesBuildPhase.files,
          isNot(contains(entry)),
        );
        expect(
          target('RunnerTests').resourcesBuildPhase.files,
          isNot(contains(entry)),
        );
        expect(entry.fileRef, isNull, reason: 'nothing lists it anymore');
      },
    );

    test('are taken out once: a second call changes nothing', () {
      removeXcconfigsFromResources(project);
      final model = project.toHash();

      removeXcconfigsFromResources(project);

      expect(project.toHash(), model);
    });
  });

  group('what the lock hashes of a project', () {
    /// A distinct UUID for each [letter]: 24 hexadecimal digits, as the project
    /// writes them. A fixture that is not one is skipped by what reads the
    /// project, and a test about it passes without classifying anything.
    String id(String letter) {
      final uuid = letter.codeUnitAt(0).toRadixString(16).toUpperCase() * 12;

      expect(uuid, matches(RegExp(r'^[0-9A-F]{24}$')));

      return uuid;
    }

    /// The definition of a file reference, on a line of its own, as the project
    /// writes it.
    String line(
      String path, {
      String uuid = 'A',
      String? type = 'text.xcconfig',
    }) =>
        '\t\t${id(uuid)} /* ${path.replaceAll('"', '')} */ = '
        '{isa = PBXFileReference; '
        '${type == null ? '' : 'lastKnownFileType = $type; '}'
        'path = $path; sourceTree = "<group>"; };';

    /// The entry that puts the file reference [file] in a phase, and the line
    /// that lists it in the phase.
    String entry(String uuid, String file, String name) =>
        '\t\t${id(uuid)} /* $name in Resources */ = '
        '{isa = PBXBuildFile; fileRef = ${id(file)} /* $name */; };';

    String listing(String uuid, String name) =>
        '\t\t\t\t${id(uuid)} /* $name in Resources */,';

    /// A project with [definitions], and the Resources phase that lists
    /// [listings].
    String project(List<String> definitions, List<String> listings) => [
      'LastUpgradeCheck = 1510;',
      '/* Begin PBXBuildFile section */',
      ...definitions,
      '/* End PBXBuildFile section */',
      '/* Begin PBXResourcesBuildPhase section */',
      '\t\t${id('R')} /* Resources */ = {',
      '\t\t\tisa = PBXResourcesBuildPhase;',
      '\t\t\tfiles = (',
      ...listings,
      '\t\t\t);',
      '\t\t};',
      '/* End PBXResourcesBuildPhase section */',
    ].join('\n');

    const other = '\t\tBBBB /* Runner */ = {isa = PBXGroup; name = Runner; };';

    test('are the references to the flavor xcconfigs of both platforms', () {
      final source = [
        'before',
        line('Flutter/appleDebug.xcconfig'),
        other,
        line('Runner/Configs/bananaRelease.xcconfig', uuid: 'B', type: null),
        line('"Flutter/my-flavorProfile.xcconfig"', uuid: 'C'),
        'after',
      ].join('\n');

      expect(
        xcconfigReferencesOwnedContent(source),
        [
          line('Flutter/appleDebug.xcconfig'),
          line('Runner/Configs/bananaRelease.xcconfig', uuid: 'B', type: null),
          line('"Flutter/my-flavorProfile.xcconfig"', uuid: 'C'),
        ].join('\n'),
      );
    });

    test('are the entries of the Resources phase that put them there, and '
        'nothing that is not theirs', () {
      final flavor = entry('C', 'A', 'appleDebug.xcconfig');
      final source = project(
        [
          line('Flutter/appleDebug.xcconfig'),
          line('Flutter/UserOverrides.xcconfig', uuid: 'U'),
          line('Other/appleDebug.xcconfig', uuid: 'O'),
          flavor,
          entry('D', 'U', 'UserOverrides.xcconfig'),
          // The annotation is the same as the one of the flavor: it is not it.
          entry('E', 'O', 'appleDebug.xcconfig'),
          '\t\t${id('F')} /* Assets.xcassets in Resources */ = '
              '{isa = PBXBuildFile; };',
        ],
        [
          listing('C', 'appleDebug.xcconfig'),
          listing('D', 'UserOverrides.xcconfig'),
          listing('E', 'appleDebug.xcconfig'),
          listing('F', 'Assets.xcassets'),
        ],
      );

      expect(
        xcconfigReferencesOwnedContent(source),
        [
          line('Flutter/appleDebug.xcconfig'),
          flavor,
          listing('C', 'appleDebug.xcconfig'),
        ].join('\n'),
      );
    });

    test('are not the entries of a phase that is not Resources', () {
      final source = [
        line('Flutter/appleDebug.xcconfig'),
        entry('C', 'A', 'appleDebug.xcconfig'),
        '/* Begin PBXCopyFilesBuildPhase section */',
        listing('C', 'appleDebug.xcconfig'),
        '/* End PBXCopyFilesBuildPhase section */',
      ].join('\n');

      expect(
        xcconfigReferencesOwnedContent(source),
        line('Flutter/appleDebug.xcconfig'),
      );
    });

    test('change when the entry of an xcconfig of the user does not, and '
        'when the entry of a flavor does', () {
      String source({required bool user, required bool flavor}) => project(
        [
          line('Flutter/appleDebug.xcconfig'),
          line('Other/appleDebug.xcconfig', uuid: 'O'),
          entry('C', 'A', 'appleDebug.xcconfig'),
          entry('E', 'O', 'appleDebug.xcconfig'),
        ],
        [
          if (flavor) listing('C', 'appleDebug.xcconfig'),
          if (user) listing('E', 'appleDebug.xcconfig'),
        ],
      );

      expect(
        xcconfigReferencesOwnedContent(source(user: true, flavor: false)),
        xcconfigReferencesOwnedContent(source(user: false, flavor: false)),
      );
      expect(
        xcconfigReferencesOwnedContent(source(user: true, flavor: true)),
        isNot(
          xcconfigReferencesOwnedContent(source(user: true, flavor: false)),
        ),
      );
    });

    test('are not the xcconfigs of Flutter or of the user', () {
      final source = [
        line('Flutter/Debug.xcconfig'),
        line('Flutter/Release.xcconfig', uuid: 'B'),
        line('Debug.xcconfig', uuid: 'C'),
        line('Flutter-Debug.xcconfig', uuid: 'D'),
        line('Runner/Configs/AppInfo.xcconfig', uuid: 'E'),
        line('Other/appleDebug.xcconfig', uuid: 'F'),
        line('Flutter/qa eastDebug.xcconfig', uuid: 'G'),
      ].join('\n');

      expect(xcconfigReferencesOwnedContent(source), isEmpty);
    });

    test('do not change when the rest of the project does', () {
      String source(String upgrade) => [
        'LastUpgradeCheck = $upgrade;',
        line('Flutter/appleDebug.xcconfig'),
      ].join('\n');

      expect(xcconfigReferencesOwnedContent(source('1510')), isNotEmpty);
      expect(
        xcconfigReferencesOwnedContent(source('1510')),
        xcconfigReferencesOwnedContent(source('1600')),
      );
    });

    test('change when a reference does', () {
      expect(
        xcconfigReferencesOwnedContent(line('Flutter/appleDebug.xcconfig')),
        isNot(
          xcconfigReferencesOwnedContent(
            line('Flutter/appleDebug.xcconfig', type: 'text'),
          ),
        ),
      );
    });

    test('are the same with Windows line endings', () {
      final lines = [line('Flutter/appleDebug.xcconfig'), other];

      expect(xcconfigReferencesOwnedContent(lines.join('\n')), isNotEmpty);
      expect(
        xcconfigReferencesOwnedContent(lines.join('\r\n')),
        xcconfigReferencesOwnedContent(lines.join('\n')),
      );
    });
  });
}
