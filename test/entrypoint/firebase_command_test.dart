/*
 * Copyright (c) 2024 Angelo Cassano
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
import 'package:flutter_flavorizr/src/engine/lock/lock_store.dart';
import 'package:flutter_flavorizr/src/engine/processors/google/firebase_processors.dart';
import 'package:flutter_flavorizr/src/entrypoint/exit_codes.dart';
import 'package:flutter_test/flutter_test.dart';

import 'cli_fixture.dart';

const _ios = 'ios/Runner.xcodeproj/project.pbxproj';
const _macos = 'macos/Runner.xcodeproj/project.pbxproj';

/// What a full run of a project with only iOS flavors covers.
const _iosRun = [
  'flutter:flavors',
  'ios:plist',
  'ios:xcconfig',
  'ios:podfile',
  'ios:firebase',
];

/// What a full run of a project with only macOS flavors covers.
const _macosRun = [
  'flutter:flavors',
  'macos:plist',
  'macos:xcconfig',
  'macos:configs',
  'macos:podfile',
  'macos:firebase',
];

String _config(
  Iterable<String> flavors, {
  String platform = 'ios',
  Iterable<String> withFirebase = const ['apple', 'banana'],
}) =>
    'flavors:\n${[for (final flavor in flavors) '''
  $flavor:
    app:
      name: "$flavor app"
    $platform:
      bundleId: "com.example.$flavor"
${withFirebase.contains(flavor) ? '''
      firebase:
        config: ".firebase/$flavor/GoogleService-Info.plist"
''' : ''}'''].join()}';

void main() {
  late CliFixture project;

  Future<XcodeProject> open(String pbxproj) => XcodeProject.open(
    project.abs(pbxproj.replaceAll('/project.pbxproj', '')),
  );

  setUp(() {
    project = CliFixture(android: false);

    for (final platform in ['ios', 'macos']) {
      project.write(
        '$platform/Runner.xcodeproj/project.pbxproj',
        File(
          'example/$platform/Runner.xcodeproj/project.pbxproj',
        ).readAsStringSync(),
      );
      project.write(
        '$platform/Podfile',
        File(
          'test_resources/darwin/podfile_test/PodfileOriginal',
        ).readAsStringSync(),
      );
    }
    for (final (platform, plist) in [
      ('ios', 'IosInfoPlistOriginal.plist'),
      ('macos', 'MacosInfoPlistOriginal.plist'),
    ]) {
      project.write(
        '$platform/Runner/Info.plist',
        File('test_resources/darwin/info_plist_test/$plist').readAsStringSync(),
      );
    }
    for (final flavor in ['apple', 'banana']) {
      project.write(
        '.firebase/$flavor/GoogleService-Info.plist',
        '$flavor-ios',
      );
      project.write(
        '.firebase/$flavor/google-services.json',
        '$flavor-android',
      );
    }
  });
  tearDown(() => project.dispose());

  /// The phases of the first target of the project.
  Future<List<PBXShellScriptBuildPhase>> phases(String pbxproj) async {
    final target = (await open(pbxproj)).targets.first as PBXNativeTarget;

    return target.shellScriptBuildPhases
        .where((phase) => phase.name == firebaseBuildPhaseName)
        .toList();
  }

  group('ios:firebase', () {
    test('copies the configuration of each flavor, writes the script and '
        'makes the phase, first of the target', () async {
      project.write(
        'flavorizr.yaml',
        _config(['apple', 'banana'], withFirebase: ['apple', 'banana']),
      );

      final code = await project.run(['apply', '--yes', ..._iosRun]);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(
        project.read('ios/Runner/apple/GoogleService-Info.plist'),
        'apple-ios',
      );
      expect(
        project.read('ios/Runner/banana/GoogleService-Info.plist'),
        'banana-ios',
      );
      expect(project.read('ios/Runner/GoogleService-Info.plist'), '');
      expect(
        project.read('ios/firebaseScript.sh'),
        'if [ "\$CONFIGURATION" == "Debug-apple" ] || '
        '[ "\$CONFIGURATION" == "Release-apple" ]; then\n'
        '  cp Runner/apple/GoogleService-Info.plist Runner/GoogleService-Info.plist\n'
        'elif [ "\$CONFIGURATION" == "Debug-banana" ] || '
        '[ "\$CONFIGURATION" == "Release-banana" ]; then\n'
        '  cp Runner/banana/GoogleService-Info.plist Runner/GoogleService-Info.plist\n'
        'fi\n\n',
      );

      final found = await phases(_ios);
      final target = (await open(_ios)).targets.first as PBXNativeTarget;

      expect(found, hasLength(1));
      expect(found.single.uuid, firebaseBuildPhaseUuid('ios'));
      expect(found.single.shellScript, project.read('ios/firebaseScript.sh'));
      expect(found.single.outputPaths, [
        r'$(SRCROOT)/Runner/GoogleService-Info.plist',
      ]);
      expect(target.buildPhases.first, isA<PBXShellScriptBuildPhase>());
    });

    test('keeps the copies and the empty file out of the lock, and a re-run '
        'changes nothing, not even the project', () async {
      project.write('flavorizr.yaml', _config(['apple', 'banana']));
      await project.run(['apply', '--yes', ..._iosRun]);
      final before = project.snapshot();

      final code = await project.run(['apply', '--yes', ..._iosRun]);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.snapshot(), before);
      expect(
        project.read('flavorizr.lock'),
        isNot(contains('GoogleService-Info.plist')),
      );
      expect(project.read('flavorizr.lock'), contains('ios/firebaseScript.sh'));
      expect(
        (await LockStore(
          project.root,
          runningVersion: '3.0.0',
        ).read())!.processors['ios:firebase']!.objects[_ios],
        contains(firebaseBuildPhaseUuid('ios')),
      );
    });

    test('is in sync after the builds copied other configurations over the '
        'empty file', () async {
      project.write('flavorizr.yaml', _config(['apple', 'banana']));
      await project.run(['apply', '--yes', ..._iosRun]);

      // What the build phase does for the flavor that is built.
      project.write('ios/Runner/GoogleService-Info.plist', 'apple-ios');
      project.write('ios/Runner/banana/GoogleService-Info.plist', 'edited');

      expect(
        await project.run(['status', ..._iosRun]),
        ExitCodes.ok,
        reason: project.logger.output,
      );
    });

    test(
      'writes the copies again, silently, when the user changes them',
      () async {
        project.write('flavorizr.yaml', _config(['apple', 'banana']));
        await project.run(['apply', '--yes', ..._iosRun]);
        project.write('ios/Runner/banana/GoogleService-Info.plist', 'edited');
        project.write(
          '.firebase/banana/GoogleService-Info.plist',
          'new banana',
        );

        final code = await project.run(['apply', '--yes', ..._iosRun]);

        expect(code, ExitCodes.ok, reason: project.logger.output);
        expect(
          project.read('ios/Runner/banana/GoogleService-Info.plist'),
          'new banana',
        );
      },
    );

    test('a flavor that loses its configuration is out of the script, and '
        'the phase stays for the other', () async {
      project.write('flavorizr.yaml', _config(['apple', 'banana']));
      await project.run(['apply', '--yes', ..._iosRun]);
      project.write(
        'flavorizr.yaml',
        _config(['apple', 'banana'], withFirebase: ['apple']),
      );

      final code = await project.run(['apply', '--yes', ..._iosRun]);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.read('ios/firebaseScript.sh'), isNot(contains('banana')));

      final found = await phases(_ios);

      expect(found, hasLength(1));
      expect(found.single.shellScript, isNot(contains('banana')));
    });

    test('loses the phase and the script when no flavor has a configuration '
        'any more', () async {
      project.write('flavorizr.yaml', _config(['apple', 'banana']));
      await project.run(['apply', '--yes', ..._iosRun]);
      project.write(
        'flavorizr.yaml',
        _config(['apple', 'banana'], withFirebase: []),
      );

      final code = await project.run(['apply', '--yes', ..._iosRun]);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(await phases(_ios), isEmpty);
      expect(project.exists('ios/firebaseScript.sh'), isFalse);
      // The copies are the builds'.
      expect(
        project.exists('ios/Runner/apple/GoogleService-Info.plist'),
        isTrue,
      );
    });

    test('replaces the phase 2.x made, which had another UUID', () async {
      project.write('flavorizr.yaml', _config(['apple', 'banana']));
      final old = await open(_ios);
      final target = old.targets.first as PBXNativeTarget;

      target.newShellScriptBuildPhase(firebaseBuildPhaseName)
        ..shellScript = 'old'
        ..outputPaths = [r'$(SRCROOT)/Runner/GoogleService-Info.plist'];
      await old.save();

      final code = await project.run(['apply', '--yes', ..._iosRun]);
      final found = await phases(_ios);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(found, hasLength(1));
      expect(found.single.uuid, firebaseBuildPhaseUuid('ios'));
      expect(found.single.shellScript, isNot('old'));
    });

    test('does not replace the empty file the project has', () async {
      project.write('flavorizr.yaml', _config(['apple', 'banana']));
      project.write(
        'ios/Runner/GoogleService-Info.plist',
        'what a build copied',
      );

      await project.run(['apply', '--yes', ..._iosRun]);

      expect(
        project.read('ios/Runner/GoogleService-Info.plist'),
        'what a build copied',
      );
    });

    test('fails when the configuration of a flavor is missing, and writes '
        'nothing', () async {
      project.write('flavorizr.yaml', _config(['apple', 'banana']));
      File(
        project.abs('.firebase/banana/GoogleService-Info.plist'),
      ).deleteSync();
      final before = project.snapshot();

      final code = await project.run(['apply', '--yes', ..._iosRun]);

      expect(code, isNot(ExitCodes.ok));
      expect(project.snapshot(), before);
    });

    test('refuses a configuration outside the project', () async {
      project.write(
        'flavorizr.yaml',
        _config(['apple'], withFirebase: []).replaceFirst(
          '      bundleId: "com.example.apple"\n',
          '      bundleId: "com.example.apple"\n'
              '      firebase:\n        config: "../outside.plist"\n',
        ),
      );
      final before = project.snapshot();

      final code = await project.run(['apply', '--yes', ..._iosRun]);

      expect(code, isNot(ExitCodes.ok));
      expect(project.snapshot(), before);
    });

    test('refuses a configuration that is a folder, or a link out of the '
        'project, and writes nothing', () async {
      final outside = Directory.systemTemp.createTempSync('firebase_outside_');
      addTearDown(() => outside.deleteSync(recursive: true));
      File('${outside.path}/GoogleService-Info.plist').writeAsStringSync('x');

      for (final prepare in [
        () => Directory(
          project.abs('.firebase/apple/folder'),
        ).createSync(recursive: true),
        () => Link(project.abs('.firebase/apple/link.plist')).createSync(
          '${outside.path}/GoogleService-Info.plist',
          recursive: true,
        ),
      ]) {
        prepare();
      }

      for (final source in ['folder', 'link.plist']) {
        project.write(
          'flavorizr.yaml',
          _config(['apple'], withFirebase: []).replaceFirst(
            '      bundleId: "com.example.apple"\n',
            '      bundleId: "com.example.apple"\n'
                '      firebase:\n        config: ".firebase/apple/$source"\n',
          ),
        );
        final before = project.snapshot();

        final code = await project.run(['apply', '--yes', ..._iosRun]);

        expect(code, isNot(ExitCodes.ok), reason: source);
        expect(project.snapshot(), before, reason: source);
      }
    });

    test('has nothing to do for a project with no configuration', () async {
      project.write('flavorizr.yaml', _config(['apple'], withFirebase: []));

      final code = await project.run(['apply', '--yes', ..._iosRun]);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.exists('ios/firebaseScript.sh'), isFalse);
      expect(await phases(_ios), isEmpty);
    });
  });

  group('macos:firebase', () {
    test('does the same in the macOS project', () async {
      project.write(
        'flavorizr.yaml',
        _config(['apple', 'banana'], platform: 'macos'),
      );

      final code = await project.run(['apply', '--yes', ..._macosRun]);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(
        project.read('macos/Runner/apple/GoogleService-Info.plist'),
        'apple-ios',
      );
      expect(project.read('macos/firebaseScript.sh'), contains('banana'));

      final found = await phases(_macos);

      expect(found.single.uuid, firebaseBuildPhaseUuid('macos'));

      final before = project.snapshot();

      await project.run(['apply', '--yes', ..._macosRun]);

      expect(project.snapshot(), before);
    });
  });

  group('android:firebase', () {
    test('copies google-services.json to the folder of each flavor, as local, '
        'and rewrites it when it is edited', () async {
      project.write(
        'flavorizr.yaml',
        'flavors:\n${[
          for (final flavor in ['apple', 'banana']) '''
  $flavor:
    app:
      name: "$flavor app"
    android:
      applicationId: "com.example.$flavor"
      firebase:
        config: ".firebase/$flavor/google-services.json"
''',
        ].join()}',
      );

      expect(
        await project.run(['apply', '--yes', 'android:firebase']),
        ExitCodes.ok,
        reason: project.logger.output,
      );
      expect(
        project.read('android/app/src/apple/google-services.json'),
        'apple-android',
      );
      expect(
        project.read('android/app/src/banana/google-services.json'),
        'banana-android',
      );
      expect(
        project.read('flavorizr.lock'),
        isNot(contains('google-services')),
      );

      project.write('android/app/src/apple/google-services.json', 'edited');

      expect(
        await project.run(['apply', '--yes', 'android:firebase']),
        ExitCodes.ok,
      );
      expect(
        project.read('android/app/src/apple/google-services.json'),
        'apple-android',
      );
    });

    test('refuses a flavor that cannot be the name of a folder', () async {
      project.write(
        'flavorizr.yaml',
        'flavors:\n  "a/b":\n    app:\n      name: ab\n    android:\n'
            '      applicationId: com.example.ab\n      firebase:\n'
            '        config: ".firebase/apple/google-services.json"\n',
      );
      final before = project.snapshot();

      final code = await project.run(['apply', '--yes', 'android:firebase']);

      expect(code, isNot(ExitCodes.ok));
      expect(project.snapshot(), before);
    });

    test('`google:firebase` is the three of them', () async {
      project.write(
        'flavorizr.yaml',
        _config(['apple'], withFirebase: ['apple']),
      );

      final code = await project.run(['plan', 'google:firebase']);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.logger.output, contains('ios:firebase'));
    });
  });
}
