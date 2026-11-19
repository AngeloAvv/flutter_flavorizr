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
import 'package:flutter_flavorizr/src/engine/darwin/pbxproj_seed.dart';
import 'package:flutter_flavorizr/src/engine/lock/lock_store.dart';
import 'package:flutter_flavorizr/src/engine/ownership.dart';
import 'package:flutter_flavorizr/src/engine/processors/darwin/xcconfig_references.dart';
import 'package:flutter_flavorizr/src/entrypoint/exit_codes.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../entrypoint/cli_fixture.dart';
import '../../darwin/pbxproj_integrity.dart';

const _iosProject = 'ios/Runner.xcodeproj';
const _macosProject = 'macos/Runner.xcodeproj';
const _iosPbxproj = '$_iosProject/project.pbxproj';
const _macosPbxproj = '$_macosProject/project.pbxproj';

/// The processors of a full run of a project with only Apple flavors.
const _targets = [
  'flutter:flavors',
  'ios:plist',
  'macos:plist',
  'ios:xcconfig',
  'macos:xcconfig',
  'macos:configs',
  'ios:podfile',
  'macos:podfile',
];

String _config(Iterable<String> flavors, {String ios = ''}) =>
    'flavors:\n${[for (final flavor in flavors) '''
  "$flavor":
    app:
      name: "${flavor[0].toUpperCase()}${flavor.substring(1)} App"
    ios:
      bundleId: "com.example.$flavor"
$ios    macos:
      bundleId: "com.example.$flavor"
'''].join()}';

/// What 2.x wrote in `ios/Flutter/<flavor><Target>.xcconfig`.
String _iosText(String flavor, String mode, String pods) =>
    '''
#include? "Pods/Target Support Files/Pods-Runner/Pods-Runner.$pods.xcconfig"
#include "Generated.xcconfig"

ASSET_PREFIX=$flavor
BUNDLE_NAME=${flavor[0].toUpperCase()}${flavor.substring(1)} App
BUNDLE_DISPLAY_NAME=${flavor[0].toUpperCase()}${flavor.substring(1)} App
''';

/// The xcconfig files that any Resources phase of [project] holds.
List<String> _xcconfigResources(XcodeProject project) => [
  for (final target in project.targets.whereType<PBXNativeTarget>())
    for (final phase in target.buildPhases.whereType<PBXResourcesBuildPhase>())
      for (final file in phase.files.map((file) => file.fileRef))
        if (file is PBXFileReference && file.path!.endsWith('.xcconfig'))
          file.path!,
];

/// The `Info.plist` of the platforms, as `flutter create` writes them.
void _writePlists(CliFixture project) {
  for (final (platform, plist) in [
    ('ios', 'IosInfoPlistOriginal.plist'),
    ('macos', 'MacosInfoPlistOriginal.plist'),
  ]) {
    project.write(
      '$platform/Runner/Info.plist',
      File('test_resources/darwin/info_plist_test/$plist').readAsStringSync(),
    );
  }
}

void main() {
  late CliFixture project;

  Future<int> apply([List<String> extra = const []]) =>
      project.run(['apply', '--yes', ...extra, ..._targets]);

  Future<XcodeProject> open(String bundle) =>
      XcodeProject.open(project.abs(bundle));

  setUp(() {
    project = CliFixture(android: false);
    project.write('flavorizr.yaml', _config(['citrus', 'dates']));
    _writePlists(project);
    for (final platform in ['ios', 'macos']) {
      project.write(
        '$platform/Runner.xcodeproj/project.pbxproj',
        File(
          'test_resources/example_2x/$platform/Runner.xcodeproj/project.pbxproj',
        ).readAsStringSync(),
      );
    }
  });
  tearDown(() => project.dispose());

  /// What the lock records for [processor] in [path]: the UUIDs of the objects
  /// it owns.
  Future<Set<String>> locked(
    String processor,
    String path, [
    CliFixture? of,
  ]) async {
    final lock = (await LockStore(
      (of ?? project).root,
      runningVersion: '3.0.0',
    ).read())!;

    return lock.processors[processor]?.objects[path] ?? {};
  }

  /// The UUID of the reference to the xcconfig at [path].
  String referenceUuid(String path, String platform) => PbxprojSeed.uuid(
    platform: platform,
    kind: ['xcconfigFileReference', ...path.split('/')],
  );

  /// The references the processors make for [flavors].
  Set<String> references(
    Iterable<String> flavors,
    String platform,
    String folder,
  ) => {
    for (final flavor in flavors)
      for (final mode in ['Debug', 'Profile', 'Release'])
        referenceUuid('$folder/$flavor$mode.xcconfig', platform),
  };

  group('apply', () {
    test('writes the flavor xcconfigs of iOS as text, with the Pods one '
        'optional', () async {
      final code = await apply();

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(
        project.read('ios/Flutter/citrusDebug.xcconfig'),
        '#include? "Pods/Target Support Files/Pods-Runner/'
        'Pods-Runner.debug.xcconfig"\n'
        '#include "Generated.xcconfig"\n'
        '\n'
        'ASSET_PREFIX=citrus\n'
        'BUNDLE_NAME=Citrus App\n'
        'BUNDLE_DISPLAY_NAME=Citrus App\n',
      );
      for (final flavor in ['citrus', 'dates']) {
        for (final target in ['Debug', 'Profile', 'Release']) {
          expect(
            project.read('ios/Flutter/$flavor$target.xcconfig'),
            startsWith('#include? "Pods/'),
            reason: '$flavor$target',
          );
        }
      }
    });

    test('keeps what the xcconfig of a flavor says, as text', () async {
      project.write(
        'flavorizr.yaml',
        _config(
          ['citrus'],
          ios: '''
      variables:
        API_URL:
          value: "https://citrus.example.com"
        DEBUG_ONLY:
          target: debug
          value: "1"
''',
        ),
      );

      await apply();

      expect(
        project.read('ios/Flutter/citrusDebug.xcconfig'),
        endsWith(
          'BUNDLE_DISPLAY_NAME=Citrus App\n'
          'API_URL=https://citrus.example.com\n'
          'DEBUG_ONLY=1\n',
        ),
      );
      expect(
        project.read('ios/Flutter/citrusRelease.xcconfig'),
        isNot(contains('DEBUG_ONLY')),
      );
    });

    test('writes the flavor xcconfigs of macOS, in Flutter and in '
        'Runner/Configs', () async {
      await apply();

      expect(
        project.read('macos/Flutter/citrusProfile.xcconfig'),
        '#include? "Pods/Target Support Files/Pods-Runner/'
        'Pods-Runner.release.xcconfig"\n'
        '#include "ephemeral/Flutter-Generated.xcconfig"\n',
      );
      expect(
        project.read('macos/Runner/Configs/citrusProfile.xcconfig'),
        '#include "../../Flutter/citrusProfile.xcconfig"\n'
        '#include "Warnings.xcconfig"\n'
        '\n'
        'ASSET_PREFIX=citrus\n'
        'BUNDLE_NAME=Citrus App\n'
        'BUNDLE_DISPLAY_NAME=Citrus App\n',
      );
    });

    test(
      'references them in the projects, and in no Resources phase',
      () async {
        await apply();

        final ios = await open(_iosProject);
        final macos = await open(_macosProject);
        final references = {
          'Flutter/citrusDebug.xcconfig': ios,
          'Flutter/datesRelease.xcconfig': ios,
          'Runner/Configs/citrusDebug.xcconfig': macos,
          'Runner/Configs/datesProfile.xcconfig': macos,
        };

        for (final MapEntry(key: path, value: xcodeproj)
            in references.entries) {
          final reference = xcodeproj.files.firstWhere(
            (file) => file.path == path,
          );

          expect(reference.lastKnownFileType, 'text.xcconfig', reason: path);
          expect(_xcconfigResources(xcodeproj), isNot(contains(path)));
        }
        for (final pbxproj in [_iosPbxproj, _macosPbxproj]) {
          expect(
            project.read(pbxproj),
            isNot(matches(RegExp(r'(citrus|dates)\w*\.xcconfig in Resources'))),
          );
        }
      },
    );

    test('records them as managed, the projects as patched', () async {
      await apply();

      final lock = (await LockStore(
        project.root,
        runningVersion: '3.0.0',
      ).read())!;

      expect(
        lock.processors['ios:xcconfig']!.files.map(
          (path, file) => MapEntry(path, file.ownership),
        ),
        {
          for (final flavor in ['citrus', 'dates'])
            for (final target in ['Debug', 'Profile', 'Release'])
              'ios/Flutter/$flavor$target.xcconfig': Ownership.managed,
          _iosPbxproj: Ownership.patched,
        },
      );
      expect(
        lock.processors['macos:configs']!.files.keys,
        contains(_macosPbxproj),
      );
      expect(
        lock.processors['macos:xcconfig']!.files.keys,
        isNot(contains(_macosPbxproj)),
      );
      // The run covered everything that applies to the project: the platforms
      // with no flavors (Android, Linux, Windows) are not waited for.
      expect(lock.flavorNames, {'citrus', 'dates'});
    });

    test(
      'records the references they made, by the UUID of their path',
      () async {
        await apply();

        expect(
          await locked('ios:xcconfig', _iosPbxproj),
          references(['citrus', 'dates'], 'ios', 'Flutter'),
        );
        expect(
          await locked('macos:configs', _macosPbxproj),
          references(['citrus', 'dates'], 'macos', 'Runner/Configs'),
        );
        expect(await locked('macos:xcconfig', _macosPbxproj), isEmpty);
        for (final uuid in await locked('ios:xcconfig', _iosPbxproj)) {
          expect(objectUuids(project.read(_iosPbxproj)), contains(uuid));
        }
      },
    );

    test(
      'hash every object they record, so that an edit of one is drift',
      () async {
        await apply();

        for (final (pbxproj, processor) in [
          (_iosPbxproj, 'ios:xcconfig'),
          (_macosPbxproj, 'macos:configs'),
        ]) {
          final owned = xcconfigReferencesOwnedContent(project.read(pbxproj));
          final uuids = await locked(processor, pbxproj);

          expect(uuids, isNotEmpty);
          for (final uuid in uuids) {
            expect(owned, contains('\t\t$uuid '), reason: '$processor $uuid');
          }
        }
      },
    );

    test(
      'make two applies from scratch write the very same projects and lock',
      () async {
        final other = CliFixture(android: false);
        addTearDown(other.dispose);
        other.write('flavorizr.yaml', _config(['citrus', 'dates']));
        _writePlists(other);
        for (final platform in ['ios', 'macos']) {
          other.write(
            '$platform/Runner.xcodeproj/project.pbxproj',
            project.read('$platform/Runner.xcodeproj/project.pbxproj'),
          );
        }

        expect(await apply(), ExitCodes.ok, reason: project.logger.output);
        expect(
          await other.run(['apply', '--yes', ..._targets]),
          ExitCodes.ok,
          reason: other.logger.output,
        );

        for (final path in [_iosPbxproj, _macosPbxproj, 'flavorizr.lock']) {
          expect(other.read(path), project.read(path), reason: path);
        }
      },
    );

    test('leaves the rest to the 2.x pipeline: nothing of this slice is '
        'handed to it', () async {
      await apply();

      expect(project.legacy.ran, isEmpty);
    });

    test('is a no-op the second time: nothing changes, the projects are not '
        'written', () async {
      await apply();
      final before = project.snapshot();
      final modified = File(project.abs(_iosPbxproj)).lastModifiedSync();

      final code = await apply();

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.snapshot(), before);
      expect(File(project.abs(_iosPbxproj)).lastModifiedSync(), modified);
    });

    test('does not mind a change of the project that is not theirs, as the '
        '2.x processors that run after the engine make', () async {
      await apply();
      for (final pbxproj in [_iosPbxproj, _macosPbxproj]) {
        project.write(
          pbxproj,
          project
              .read(pbxproj)
              .replaceFirst(
                RegExp(r'LastUpgradeCheck = \d+;'),
                'LastUpgradeCheck = 9999;',
              ),
        );
      }
      final before = project.snapshot();

      final code = await apply();

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.snapshot(), before);
    });

    test(
      'reports a hand edit of an xcconfig as a conflict, and keeps it',
      () async {
        await apply();
        project.write('ios/Flutter/citrusDebug.xcconfig', '// mine\n');

        final code = await apply();

        expect(code, ExitCodes.attention, reason: project.logger.output);
        expect(project.read('ios/Flutter/citrusDebug.xcconfig'), '// mine\n');
      },
    );

    test('writes nothing in a dry run', () async {
      final before = project.snapshot();

      final code = await project.run(['plan', ..._targets]);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.snapshot(), before);
    });

    test('removes the xcconfigs of a flavor that was dropped, and only '
        'those', () async {
      await apply();

      project.write('flavorizr.yaml', _config(['citrus']));
      final code = await apply();

      expect(code, ExitCodes.ok, reason: project.logger.output);
      for (final path in [
        'ios/Flutter/datesDebug.xcconfig',
        'macos/Flutter/datesRelease.xcconfig',
        'macos/Runner/Configs/datesProfile.xcconfig',
      ]) {
        expect(project.exists(path), isFalse, reason: path);
      }
      for (final path in [
        'ios/Flutter/citrusDebug.xcconfig',
        'macos/Flutter/citrusRelease.xcconfig',
        'macos/Runner/Configs/citrusProfile.xcconfig',
      ]) {
        expect(project.exists(path), isTrue, reason: path);
      }

      final lock = (await LockStore(
        project.root,
        runningVersion: '3.0.0',
      ).read())!;
      expect(
        lock.processors.values.expand((p) => p.files.keys),
        everyElement(isNot(contains('dates'))),
      );
    });

    test('removes the references of a flavor that was dropped, by UUID, and '
        'leaves what a run from scratch of the flavors that remain would '
        'write', () async {
      final fresh = CliFixture(android: false);
      addTearDown(fresh.dispose);
      fresh.write('flavorizr.yaml', _config(['citrus']));
      _writePlists(fresh);
      for (final platform in ['ios', 'macos']) {
        fresh.write(
          '$platform/Runner.xcodeproj/project.pbxproj',
          project.read('$platform/Runner.xcodeproj/project.pbxproj'),
        );
      }
      await apply();
      for (final pbxproj in [_iosPbxproj, _macosPbxproj]) {
        expect(project.read(pbxproj), contains('dates'), reason: pbxproj);
      }

      project.write('flavorizr.yaml', _config(['citrus']));
      final code = await apply();
      await fresh.run(['apply', '--yes', ..._targets]);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      for (final pbxproj in [_iosPbxproj, _macosPbxproj]) {
        final text = project.read(pbxproj);

        expect(text, isNot(contains('dates')), reason: pbxproj);
        expect(danglingUuids(text), isEmpty, reason: pbxproj);
        expect(text, fresh.read(pbxproj), reason: pbxproj);
      }
      expect(
        await locked('ios:xcconfig', _iosPbxproj),
        references(['citrus'], 'ios', 'Flutter'),
      );
      expect(
        await locked('macos:configs', _macosPbxproj),
        references(['citrus'], 'macos', 'Runner/Configs'),
      );
    });

    test('keeps what an xcconfig of the user has in the same folder', () async {
      project.write('ios/Flutter/Mine.xcconfig', '// mine\n');

      await apply();
      project.write('flavorizr.yaml', _config(['citrus']));
      await apply();

      expect(project.read('ios/Flutter/Mine.xcconfig'), '// mine\n');
    });
  });

  group('apply on a project 2.x flavorized', () {
    setUp(() {
      project.write('flavorizr.yaml', _config(['apple', 'banana']));
      // What 2.x wrote.
      for (final flavor in ['apple', 'banana']) {
        project.write(
          'ios/Flutter/${flavor}Debug.xcconfig',
          _iosText(flavor, 'Debug', 'debug'),
        );
        project.write(
          'ios/Flutter/${flavor}Profile.xcconfig',
          _iosText(flavor, 'Profile', 'release'),
        );
        project.write(
          'ios/Flutter/${flavor}Release.xcconfig',
          _iosText(flavor, 'Release', 'release'),
        );
      }
    });

    test('takes the xcconfigs out of the Resources phase, which is where 2.x '
        'put them', () async {
      expect(
        _xcconfigResources(await open(_iosProject)),
        hasLength(6),
        reason: 'the fixture is a project 2.x flavorized',
      );
      expect(_xcconfigResources(await open(_macosProject)), hasLength(6));

      final code = await apply();

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(_xcconfigResources(await open(_iosProject)), isEmpty);
      expect(_xcconfigResources(await open(_macosProject)), isEmpty);
      expect(
        project.read(_iosPbxproj),
        isNot(contains('xcconfig in Resources')),
      );
      expect(
        project.read(_macosPbxproj),
        isNot(contains('xcconfig in Resources')),
      );
    });

    test('takes them out for the flavors that flavorizr.yaml has not anymore, '
        'which no lock tells apart from the ones of the user', () async {
      project.write('flavorizr.yaml', _config(['citrus']));
      expect(_xcconfigResources(await open(_iosProject)), hasLength(6));
      expect(_xcconfigResources(await open(_macosProject)), hasLength(6));

      final code = await apply();

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(_xcconfigResources(await open(_iosProject)), isEmpty);
      expect(_xcconfigResources(await open(_macosProject)), isEmpty);
    });

    test('leaves the xcconfigs that are not named like the ones of a '
        'flavor, wherever they are', () async {
      for (final platform in ['ios', 'macos']) {
        final path = '$platform/Runner.xcodeproj';
        final xcodeproj = await open(path);
        final target = xcodeproj.targets.whereType<PBXNativeTarget>().first;
        final mine = xcodeproj.newObject<PBXFileReference>(
          (g, u) => PBXFileReference(g, u),
        );
        mine.path = 'Shared/mine.xcconfig';
        mine.sourceTree = '<group>';
        xcodeproj.mainGroup.children.add(mine);
        target.resourcesBuildPhase.addFileReference(mine);
        await xcodeproj.save();
      }

      final code = await apply();

      expect(code, ExitCodes.ok, reason: project.logger.output);
      for (final path in [_iosProject, _macosProject]) {
        expect(_xcconfigResources(await open(path)), ['Shared/mine.xcconfig']);
      }
    });

    test('uses the references 2.x made, with no duplicate, and owns none of '
        'them: only the lock can tell whose they are', () async {
      final iosBefore = objectUuids(project.read(_iosPbxproj));

      final code = await apply();

      expect(code, ExitCodes.ok, reason: project.logger.output);
      for (final (bundle, path) in [
        (_iosProject, 'Flutter/appleDebug.xcconfig'),
        (_macosProject, 'Runner/Configs/bananaRelease.xcconfig'),
      ]) {
        final opened = await open(bundle);

        expect(
          opened.files.where((file) => file.path == path),
          hasLength(1),
          reason: path,
        );
      }
      // Nothing was created: what went is the 6 entries in Resources.
      final iosAfter = objectUuids(project.read(_iosPbxproj));
      expect(iosAfter.difference(iosBefore), isEmpty);
      expect(iosBefore.difference(iosAfter), hasLength(6));
      expect(await locked('ios:xcconfig', _iosPbxproj), isEmpty);
      expect(await locked('macos:configs', _macosPbxproj), isEmpty);
    });

    test('keeps the references 2.x made when a flavor is dropped, with no '
        'dangling reference, though the files go', () async {
      await apply();

      project.write('flavorizr.yaml', _config(['apple']));
      final code = await apply();

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.exists('ios/Flutter/bananaDebug.xcconfig'), isFalse);
      for (final pbxproj in [_iosPbxproj, _macosPbxproj]) {
        final text = project.read(pbxproj);

        expect(text, contains('banana'), reason: pbxproj);
        expect(danglingUuids(text), isEmpty, reason: pbxproj);
        expect(text, isNot(contains('xcconfig in Resources')), reason: pbxproj);
      }
    });

    test('is done after one more run, which changes nothing', () async {
      await apply();
      final before = project.snapshot();

      final code = await apply();

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.snapshot(), before);
    });
  });

  group('a flavor that is not a name for a file', () {
    for (final name in ['a/b', '..', 'qa east', 'a;b', 'a*b', 'é']) {
      test('`$name` fails the run, which writes nothing', () async {
        project.write('flavorizr.yaml', _config([name]));
        final before = project.snapshot();

        final code = await apply();

        expect(code, ExitCodes.software, reason: project.logger.output);
        expect(project.logger.output, contains('as the name of a file'));
        expect(project.snapshot(), before);
      });
    }
  });

  group('macos:xcconfig', () {
    test('needs no Xcode project: it only writes text', () async {
      File(project.abs(_macosPbxproj)).deleteSync();

      final code = await project.run(['apply', '--yes', 'macos:xcconfig']);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.exists('macos/Flutter/citrusDebug.xcconfig'), isTrue);
    });
  });

  group('ios:xcconfig', () {
    test('fails, writing nothing, when there is no Xcode project', () async {
      File(project.abs(_iosPbxproj)).deleteSync();
      final before = project.snapshot();

      final code = await project.run(['apply', '--yes', 'ios:xcconfig']);

      expect(code, isNot(ExitCodes.ok));
      expect(project.snapshot(), before);
    });
  });
}
