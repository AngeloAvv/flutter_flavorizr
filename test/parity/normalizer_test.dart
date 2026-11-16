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

import 'package:flutter_test/flutter_test.dart';

import '../../tool/parity/src/normalizer.dart';

/// Builds a minimal but structurally realistic `project.pbxproj`.
///
/// Xcode sorts the entries of every section by UUID, so changing the UUIDs
/// also changes the order of the lines: exactly what makes two flavorizr runs
/// differ even when they do the same thing.
String pbxproj(Map<String, String> id, {String file = 'apple.xcconfig'}) {
  String section(String name, Map<String, String> entries) {
    final sorted = entries.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return '/* Begin $name section */\n'
        '${sorted.map((e) => e.value).join()}'
        '/* End $name section */\n';
  }

  return '// !\$*UTF8*\$!\n'
      '{\n'
      '\tarchiveVersion = 1;\n'
      '\tobjects = {\n\n'
      '${section('PBXBuildFile', {id['buildFile']!: '\t\t${id['buildFile']} /* $file in Resources */ = '
          '{isa = PBXBuildFile; fileRef = ${id['file']} /* $file */; };\n'})}\n'
      '${section('PBXFileReference', {id['file']!: '\t\t${id['file']} /* $file */ = '
          '{isa = PBXFileReference; lastKnownFileType = text.xcconfig; '
          'path = $file; sourceTree = "<group>"; };\n'})}\n'
      '${section('PBXGroup', {id['group']!: '\t\t${id['group']} /* Flutter */ = {\n'
          '\t\t\tisa = PBXGroup;\n'
          '\t\t\tchildren = (\n'
          '\t\t\t\t${id['file']} /* $file */,\n'
          '\t\t\t);\n'
          '\t\t\tpath = Flutter;\n'
          '\t\t\tsourceTree = "<group>";\n'
          '\t\t};\n'})}\n'
      '${section('PBXResourcesBuildPhase', {id['phase']!: '\t\t${id['phase']} /* Resources */ = {\n'
          '\t\t\tisa = PBXResourcesBuildPhase;\n'
          '\t\t\tfiles = (\n'
          '\t\t\t\t${id['buildFile']} /* $file in Resources */,\n'
          '\t\t\t);\n'
          '\t\t};\n'})}\n'
      '${section('PBXNativeTarget', {id['target']!: '\t\t${id['target']} /* Runner */ = {\n'
          '\t\t\tisa = PBXNativeTarget;\n'
          '\t\t\tbuildPhases = (\n'
          '\t\t\t\t${id['phase']} /* Resources */,\n'
          '\t\t\t);\n'
          '\t\t\tname = Runner;\n'
          '\t\t};\n'})}\n'
      '${section('PBXProject', {id['project']!: '\t\t${id['project']} /* Project object */ = {\n'
          '\t\t\tisa = PBXProject;\n'
          '\t\t\tmainGroup = ${id['group']} /* Flutter */;\n'
          '\t\t\ttargets = (\n'
          '\t\t\t\t${id['target']} /* Runner */,\n'
          '\t\t\t);\n'
          '\t\t};\n'})}'
      '\t};\n'
      '\trootObject = ${id['project']} /* Project object */;\n'
      '}\n';
}

/// A project with two targets whose `TargetAttributes` are keyed by UUID.
///
/// Xcode lists a dictionary sorted by key, so the order of the attributes
/// follows the UUIDs, while the `targets` list keeps its own stable order.
String pbxprojWithTargetAttributes({
  required String runner,
  required String tests,
  required String project,
}) {
  final attributes = {
    runner:
        '\t\t\t\t\t$runner = {\n'
        '\t\t\t\t\t\tLastSwiftMigration = 1100;\n'
        '\t\t\t\t\t};\n',
    tests:
        '\t\t\t\t\t$tests = {\n'
        '\t\t\t\t\t\tTestTargetID = $runner /* Runner */;\n'
        '\t\t\t\t\t};\n',
  };
  final sorted = attributes.keys.toList()..sort();

  return '// !\$*UTF8*\$!\n'
      '{\n'
      '\tarchiveVersion = 1;\n'
      '\tobjects = {\n\n'
      '/* Begin PBXNativeTarget section */\n'
      '${([(runner, 'Runner'), (tests, 'RunnerTests')]..sort((a, b) => a.$1.compareTo(b.$1))).map((t) => '\t\t${t.$1} /* ${t.$2} */ = {\n'
          '\t\t\tisa = PBXNativeTarget;\n'
          '\t\t\tname = ${t.$2};\n'
          '\t\t};\n').join()}'
      '/* End PBXNativeTarget section */\n\n'
      '/* Begin PBXProject section */\n'
      '\t\t$project /* Project object */ = {\n'
      '\t\t\tisa = PBXProject;\n'
      '\t\t\tattributes = {\n'
      '\t\t\t\tTargetAttributes = {\n'
      '${sorted.map((id) => attributes[id]).join()}'
      '\t\t\t\t};\n'
      '\t\t\t};\n'
      '\t\t\ttargets = (\n'
      '\t\t\t\t$runner /* Runner */,\n'
      '\t\t\t\t$tests /* RunnerTests */,\n'
      '\t\t\t);\n'
      '\t\t};\n'
      '/* End PBXProject section */\n'
      '\t};\n'
      '\trootObject = $project /* Project object */;\n'
      '}\n';
}

const _idsA = {
  'buildFile': '0868D4205153D197A65C2988',
  'file': 'BFCEED3170A6FC0D94A55841',
  'group': '7327877F5D15C7E97B6B6AD2',
  'phase': '2C1C66A6C898B88DECC4388A',
  'target': '7E0AFE57A4E7217D0E45196F',
  'project': 'C51DFACEF00DEFE31527F72E',
};

// Same logical project, but every UUID is different and sorts differently.
const _idsB = {
  'buildFile': 'F00000000000000000000001',
  'file': 'E00000000000000000000002',
  'group': 'D00000000000000000000003',
  'phase': '100000000000000000000004',
  'target': '200000000000000000000005',
  'project': '300000000000000000000006',
};

void main() {
  const normalizer = Normalizer();
  const path = 'ios/Runner.xcodeproj/project.pbxproj';

  group('line endings', () {
    test('CRLF and LF normalize to the same content', () {
      // git may rewrite the line endings of a committed golden.
      expect(
        normalizer.normalize('android/gradlew.bat', '@echo off\r\nexit 0\r\n'),
        normalizer.normalize('android/gradlew.bat', '@echo off\nexit 0\n'),
      );
    });
  });

  group('copyright year', () {
    test(
      'the year flutter create stamps in the Windows resources is stripped',
      () {
        // Runner.rc is generated with the year of the day it is created.
        const rc =
            'VALUE "LegalCopyright", "Copyright (C) 2026 com.example. All rights reserved."\n';

        expect(
          normalizer.normalize('windows/runner/Runner.rc', rc),
          normalizer.normalize(
            'windows/runner/Runner.rc',
            rc.replaceFirst('2026', '2031'),
          ),
        );
      },
    );

    test('other years are left alone', () {
      const content = 'version 2026 of the spec\n';

      expect(normalizer.normalize('README.md', content), content);
    });
  });

  group('timestamps', () {
    test('ISO 8601 timestamps are stripped from any text file', () {
      const first = '# Generated on 2026-11-16T10:20:30.123Z by flavorizr\n';
      const second = '# Generated on 2027-01-02 03:04:05 by flavorizr\n';

      expect(
        normalizer.normalize('android/app/flavorizr.gradle', first),
        normalizer.normalize('android/app/flavorizr.gradle', second),
      );
    });

    test('text without timestamps is left untouched', () {
      const content = 'applicationId "com.example.apple"\nversion 1.0.0+1\n';

      expect(
        normalizer.normalize('android/app/build.gradle', content),
        content,
      );
    });
  });

  group('pubspec.yaml', () {
    const header =
        'name: parity_app\ndev_dependencies:\n  flutter_test:\n'
        '    sdk: flutter\n';
    const footer =
        '  flutter_lints: ^6.0.0\nflutter:\n  uses-material-design: true\n';

    test('does not depend on where flavorizr comes from', () {
      const fromPub = '$header  flutter_flavorizr: 2.6.0\n$footer';
      const fromPath =
          '$header  flutter_flavorizr:\n'
          '    path: /Users/someone/flutter_flavorizr\n$footer';

      expect(
        normalizer.normalize('pubspec.yaml', fromPub),
        normalizer.normalize('pubspec.yaml', fromPath),
      );
    });

    test('keeps every other dependency', () {
      const content = '$header  flutter_flavorizr: 2.6.0\n$footer';

      final normalized = normalizer.normalize('pubspec.yaml', content);

      expect(normalized, contains('  flutter_test:\n    sdk: flutter\n'));
      expect(normalized, contains('  flutter_lints: ^6.0.0\n'));
      expect(normalized, isNot(contains('flutter_flavorizr')));
    });
  });

  group('pbxproj', () {
    test(
      'same project with different UUIDs normalizes to the same content',
      () {
        final runA = pbxproj(_idsA);
        final runB = pbxproj(_idsB);
        expect(runA, isNot(runB), reason: 'precondition: raw runs must differ');

        expect(
          normalizer.normalize(path, runA),
          normalizer.normalize(path, runB),
        );
      },
    );

    test(
      'a real structural difference is still reported after normalizing',
      () {
        final apple = pbxproj(_idsA, file: 'apple.xcconfig');
        final banana = pbxproj(_idsB, file: 'banana.xcconfig');

        expect(
          normalizer.normalize(path, apple),
          isNot(normalizer.normalize(path, banana)),
        );
      },
    );

    test('the Apple team of the machine is not part of the output', () {
      // `flutter create` copies it from the local Xcode, so it depends on who
      // ran it: a Linux runner has none.
      final without = pbxproj(_idsA);
      final withTeam = without.replaceFirst(
        'isa = PBXNativeTarget;\n',
        'isa = PBXNativeTarget;\n\t\t\tDEVELOPMENT_TEAM = ABCDE12345;\n',
      );
      expect(withTeam, isNot(without), reason: 'precondition');

      expect(
        normalizer.normalize(path, withTeam),
        normalizer.normalize(path, without),
      );
    });

    test('an unterminated comment is reported instead of looping forever', () {
      expect(
        () => normalizer.normalize(path, '{ objects = { }; } /* never closed'),
        throwsFormatException,
      );
    });

    test('target identities do not depend on the UUID order of the '
        'TargetAttributes', () {
      // Runner sorts before RunnerTests in one run and after it in the other.
      final first = pbxprojWithTargetAttributes(
        runner: '1000000000000000000000AA',
        tests: '2000000000000000000000BB',
        project: '3000000000000000000000CC',
      );
      final second = pbxprojWithTargetAttributes(
        runner: 'F000000000000000000000AA',
        tests: 'E000000000000000000000BB',
        project: 'D000000000000000000000CC',
      );
      expect(first, isNot(second), reason: 'precondition');

      expect(
        normalizer.normalize(path, first),
        normalizer.normalize(path, second),
      );
    });

    test('UUIDs are rewritten, not left untouched', () {
      final normalized = normalizer.normalize(path, pbxproj(_idsA));

      for (final uuid in _idsA.values) {
        expect(normalized, isNot(contains(uuid)));
      }
    });
  });
}
