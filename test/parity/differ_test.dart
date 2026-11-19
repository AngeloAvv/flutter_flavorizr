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

import 'package:test/test.dart';
import 'package:path/path.dart' as p;

import 'package:flutter_flavorizr/src/engine/processors/darwin/xcconfig_naming.dart';

import '../../tool/parity/src/differ.dart';
import '../../tool/parity/src/pbxproj_normalizer.dart';

/// [path] as a plist writes it: quoted unless it is made of plain characters.
String _quoted(String path) =>
    RegExp(r'^[A-Za-z0-9_./]+$').hasMatch(path) ? path : '"$path"';

void main() {
  late Directory golden;
  late Directory actual;

  setUp(() {
    final root = Directory.systemTemp.createTempSync('parity_differ_');
    golden = Directory(p.join(root.path, 'golden'))..createSync();
    actual = Directory(p.join(root.path, 'actual'))..createSync();
    addTearDown(() => root.deleteSync(recursive: true));
  });

  void write(Directory tree, String path, String content) {
    File(p.join(tree.path, path))
      ..createSync(recursive: true)
      ..writeAsStringSync(content);
  }

  group('compareTrees', () {
    test('identical trees are clean', () {
      write(golden, 'android/app/build.gradle', 'a\n');
      write(actual, 'android/app/build.gradle', 'a\n');

      final report = compareTrees(golden, actual);

      expect(report.differences, isEmpty);
      expect(report.isClean, isTrue);
    });

    test('reports a changed file with the lines that changed', () {
      write(golden, 'lib/main.dart', 'one\ntwo\nthree\n');
      write(actual, 'lib/main.dart', 'one\n2\nthree\n');

      final report = compareTrees(golden, actual);

      expect(report.isClean, isFalse);
      expect(report.differences, hasLength(1));
      final difference = report.differences.single;
      expect(difference.path, 'lib/main.dart');
      expect(difference.kind, DifferenceKind.changed);
      expect(difference.diff, '-two\n+2\n');
    });

    test('reports files that were added or removed', () {
      write(golden, 'removed.txt', 'x\n');
      write(actual, 'added.txt', 'y\n');

      final report = compareTrees(golden, actual);

      expect(
        {for (final d in report.differences) d.path: d.kind},
        {
          'added.txt': DifferenceKind.added,
          'removed.txt': DifferenceKind.removed,
        },
      );
    });

    test(
      'a whitelisted difference is reported with its reason but is clean',
      () {
        write(
          golden,
          'android/app/src/main/res/mipmap/ic_launcher.png.sha256',
          'old\n',
        );
        write(
          actual,
          'android/app/src/main/res/mipmap/ic_launcher.png.sha256',
          'new\n',
        );
        final whitelist = Whitelist.parse('''
- path: android/app/src/main/res/**
  reason: M5 removes the dummy assets on purpose
''');

        final report = compareTrees(golden, actual, whitelist: whitelist);

        expect(report.isClean, isTrue);
        expect(
          report.differences.single.reason,
          'M5 removes the dummy assets on purpose',
        );
      },
    );

    test('a whitelist entry does not hide differences in other files', () {
      write(golden, 'lib/main.dart', 'a\n');
      write(actual, 'lib/main.dart', 'b\n');
      final whitelist = Whitelist.parse('''
- path: android/**
  reason: unrelated
''');

      final report = compareTrees(golden, actual, whitelist: whitelist);

      expect(report.isClean, isFalse);
      expect(report.differences.single.reason, isNull);
    });
  });

  group('the whitelist of the Firebase script, as it ships', () {
    final whitelist = Whitelist.parse(
      File('tool/parity/whitelist.yaml').readAsStringSync(),
    );

    String script(Iterable<String> flavors, {required bool profile}) => [
      for (final flavor in flavors)
        'if [ "\$CONFIGURATION" == "Debug-$flavor" ]'
            '${profile ? ' || [ "\$CONFIGURATION" == "Profile-$flavor" ]' : ''}'
            ' || [ "\$CONFIGURATION" == "Release-$flavor" ]; then\n'
            '  cp Runner/$flavor/GoogleService-Info.plist '
            'Runner/GoogleService-Info.plist\n',
    ].join('fi\n');

    for (final flavors in [
      ['apple'],
      ['dev-1', 'v2.0'],
    ]) {
      test('takes the Profile case of $flavors', () {
        write(golden, 'ios/firebaseScript.sh', script(flavors, profile: false));
        write(actual, 'ios/firebaseScript.sh', script(flavors, profile: true));

        expect(
          compareTrees(golden, actual, whitelist: whitelist).isClean,
          isTrue,
        );
      });
    }

    test('does not take a Profile case of another flavor', () {
      const golden0 =
          'if [ "\$CONFIGURATION" == "Debug-apple" ] || '
          '[ "\$CONFIGURATION" == "Release-apple" ]; then\n';
      const actual0 =
          'if [ "\$CONFIGURATION" == "Debug-apple" ] || '
          '[ "\$CONFIGURATION" == "Profile-banana" ] || '
          '[ "\$CONFIGURATION" == "Release-apple" ]; then\n';

      write(golden, 'ios/firebaseScript.sh', golden0);
      write(actual, 'ios/firebaseScript.sh', actual0);

      expect(
        compareTrees(golden, actual, whitelist: whitelist).isClean,
        isFalse,
      );
    });

    test('does not take another change of the script', () {
      write(golden, 'ios/firebaseScript.sh', script(['apple'], profile: false));
      write(
        actual,
        'ios/firebaseScript.sh',
        script(['apple'], profile: true).replaceAll('Runner/apple', 'Other'),
      );

      expect(
        compareTrees(golden, actual, whitelist: whitelist).isClean,
        isFalse,
      );
    });
  });

  group('the whitelist of the schemes, as it ships', () {
    final whitelist = Whitelist.parse(
      File('tool/parity/whitelist.yaml').readAsStringSync(),
    );
    const schemes = 'ios/Runner.xcodeproj/xcshareddata/xcschemes';
    const preActions = '''
      <PreActions>
         <ExecutionAction
            ActionType = "Xcode.IDEStandardExecutionActionsCore.ExecutionActionType.ShellScriptAction">
            <ActionContent
               title = "Run Prepare Flutter Framework Script"
               scriptText = "/bin/sh &quot;\$FLUTTER_ROOT/packages/flutter_tools/bin/xcode_backend.sh&quot; prepare&#10;">
               <EnvironmentBuildable>
                  <BuildableReference
                     BuildableIdentifier = "primary"
                     BlueprintIdentifier = "97C146ED1CF9000F007C117D"
                     BuildableName = "Runner.app"
                     BlueprintName = "Runner"
                     ReferencedContainer = "container:Runner.xcodeproj">
                  </BuildableReference>
               </EnvironmentBuildable>
            </ActionContent>
         </ExecutionAction>
      </PreActions>
''';
    const entries = '''
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "97C146ED1CF9000F007C117D"
               BuildableName = "Runner.app"
               BlueprintName = "Runner"
               ReferencedContainer = "container:Runner.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
''';
    const open = '''
<Scheme
   version = "1.3">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
''';
    const close = '''
   </BuildAction>
   <LaunchAction
      buildConfiguration = "Debug-apple">
   </LaunchAction>
</Scheme>
''';

    bool clean(String before, String after, {String path = 'apple'}) {
      write(golden, '$schemes/$path.xcscheme', before);
      write(actual, '$schemes/$path.xcscheme', after);

      return compareTrees(golden, actual, whitelist: whitelist).isClean;
    }

    test(
      'takes the pre-action of Flutter and the entry that builds the app',
      () {
        expect(clean('$open$close', '$open$preActions$entries$close'), isTrue);
        expect(
          clean('$open$close', '$open$preActions$entries$close', path: 'dev-1'),
          isTrue,
        );
      },
    );

    test('does not take the schemes of macOS', () {
      write(
        golden,
        'macos/Runner.xcodeproj/xcshareddata/xcschemes/a.xcscheme',
        '$open$close',
      );
      write(
        actual,
        'macos/Runner.xcodeproj/xcshareddata/xcschemes/a.xcscheme',
        '$open$preActions$entries$close',
      );

      expect(
        compareTrees(golden, actual, whitelist: whitelist).isClean,
        isFalse,
      );
    });

    test('does not take another script', () {
      final other = preActions.replaceAll('xcode_backend', 'evil');

      expect(clean('$open$close', '$open$other$entries$close'), isFalse);
    });

    test('does not take a change of a build configuration', () {
      expect(
        clean(
          '$open$close',
          '$open$preActions$entries$close'.replaceAll('Debug-apple', 'Debug'),
        ),
        isFalse,
      );
    });

    test('does not take another type of action', () {
      final bogus = preActions.replaceAll(
        'ExecutionActionType.ShellScriptAction',
        'ExecutionActionType.BogusShellScriptAction',
      );

      expect(clean('$open$close', '$open$bogus$entries$close'), isFalse);
    });

    for (final (name, from, to) in [
      (
        'another target',
        'BlueprintIdentifier = "97C146ED1CF9000F007C117D"',
        'BlueprintIdentifier = "331C8080294A63A400263BE5"',
      ),
      (
        'another product',
        'BuildableName = "Runner.app"',
        'BuildableName = "RunnerTests.xctest"',
      ),
      (
        'another container',
        'container:Runner.xcodeproj',
        'container:Other.xcodeproj',
      ),
    ]) {
      test('does not take a build entry for $name', () {
        final other = entries.replaceAll(from, to);

        expect(other, isNot(entries));
        expect(clean('$open$close', '$open$preActions$other$close'), isFalse);
      });

      test('does not take a pre-action for $name', () {
        final other = preActions.replaceAll(from, to);

        expect(other, isNot(preActions));
        expect(clean('$open$close', '$open$other$entries$close'), isFalse);
      });
    }

    test('does not take a pre-action or an entry that is there twice', () {
      for (final actual in [
        '$open$preActions$preActions$entries$close',
        '$open$preActions$entries$entries$close',
        '$open$preActions$preActions$close',
        '$open$entries$entries$close',
      ]) {
        expect(clean('$open$close', actual), isFalse, reason: actual);
      }
    });

    test('does not take a build entry that repeats a flag and misses one', () {
      final repeated = entries.replaceAll(
        'buildForRunning = "YES"',
        'buildForTesting = "YES"',
      );

      expect(repeated, isNot(entries));
      expect(clean('$open$close', '$open$preActions$repeated$close'), isFalse);
    });

    test('does not take a build entry with a flag more or less', () {
      final more = entries.replaceAll(
        'buildForAnalyzing = "YES">',
        'buildForAnalyzing = "YES"\n            buildForAnalyzing = "YES">',
      );
      final less = entries.replaceAll(
        '            buildForArchiving = "YES"\n',
        '',
      );

      for (final other in [more, less]) {
        expect(other, isNot(entries));
        expect(clean('$open$close', '$open$preActions$other$close'), isFalse);
      }
    });

    test('does not take a build entry that does not build for everything', () {
      final partial = entries.replaceAll(
        'buildForTesting = "YES"',
        'buildForTesting = "NO"',
      );

      expect(clean('$open$close', '$open$preActions$partial$close'), isFalse);
    });
  });

  group('an ignore-once whitelist entry', () {
    final whitelist = Whitelist.parse(r'''
- path: a.txt
  ignore-once:
    - '^x\n'
  reason: It has one x line
''');

    bool clean(String before, String after) {
      write(golden, 'a.txt', before);
      write(actual, 'a.txt', after);

      return compareTrees(golden, actual, whitelist: whitelist).isClean;
    }

    test('takes what it matches once', () {
      expect(clean('a\n', 'x\na\n'), isTrue);
    });

    test('does not take what it matches twice', () {
      expect(clean('a\n', 'x\nx\na\n'), isFalse);
    });

    test('does not take it in the golden twice either', () {
      expect(clean('x\nx\na\n', 'a\n'), isFalse);
    });

    group('with patterns that overlap', () {
      Whitelist two(String first, String second) => Whitelist.parse('''
- path: a.txt
  ignore-once:
    - '$first'
    - '$second'
  reason: It has them once
''');

      bool cleanWith(Whitelist whitelist, String before, String after) {
        write(golden, 'a.txt', before);
        write(actual, 'a.txt', after);

        return compareTrees(golden, actual, whitelist: whitelist).isClean;
      }

      test('counts each on the text as it is, not after the others', () {
        // Removing the first would leave the second once.
        for (final patterns in [(r'^x\ny\n', r'^x\n'), (r'^x\n', r'^x\ny\n')]) {
          final whitelist = two(patterns.$1, patterns.$2);

          expect(
            cleanWith(whitelist, 'tail\n', 'x\ny\nx\ntail\n'),
            isFalse,
            reason: '$patterns',
          );
          expect(
            cleanWith(whitelist, 'x\ny\nx\ntail\n', 'tail\n'),
            isFalse,
            reason: '$patterns',
          );
        }
      });

      test('takes what both match once, whatever their order', () {
        for (final patterns in [
          (r'^x\ny\n', r'^y\nz\n'),
          (r'^y\nz\n', r'^x\ny\n'),
        ]) {
          expect(
            cleanWith(
              two(patterns.$1, patterns.$2),
              'tail\n',
              'x\ny\nz\ntail\n',
            ),
            isTrue,
            reason: '$patterns',
          );
        }
      });
    });

    test('is rejected when it is not a list of patterns', () {
      expect(
        () => Whitelist.parse('''
- path: a.txt
  ignore-once: x
  reason: nope
'''),
        throwsFormatException,
      );
    });
  });

  group('a moved whitelist entry', () {
    final whitelist = Whitelist.parse(r'''
- path: ios/Runner.xcodeproj/project.pbxproj
  only-comments: true
  moved: '^\s*\w{24} /\* M(?: in Resources)? \*/(?: = \{isa = \w+;.*\};|,)$'
  reason: It is in another place
''');
    const pbxproj = 'ios/Runner.xcodeproj/project.pbxproj';
    const m = 'AAAAAAAAAAAAAAAAAAAAAAAA';
    const mBuild = 'BBBBBBBBBBBBBBBBBBBBBBBB';
    const other = 'CCCCCCCCCCCCCCCCCCCCCCCC';
    const otherBuild = 'DDDDDDDDDDDDDDDDDDDDDDDD';
    const phase = 'EEEEEEEEEEEEEEEEEEEEEEEE';

    /// A project with a Resources phase that lists [entries] and a Sources
    /// phase that lists [sources].
    String project({
      List<String> entries = const [],
      List<String> testEntries = const [],
      List<String> sources = const [],
      String path = 'm',
      String buildOf = m,
      bool reference = true,
      bool build = true,
    }) =>
        '''
/* Begin PBXBuildFile section */
${build ? '\t\t$mBuild /* M in Resources */ = {isa = PBXBuildFile; fileRef = $buildOf; };\n' : ''}\t\t$otherBuild /* Other in Resources */ = {isa = PBXBuildFile; fileRef = $other; };
/* End PBXBuildFile section */
/* Begin PBXFileReference section */
${reference ? '\t\t$m /* M */ = {isa = PBXFileReference; path = $path; sourceTree = "<group>"; };\n' : ''}\t\t$other /* Other */ = {isa = PBXFileReference; path = o; sourceTree = "<group>"; };
/* End PBXFileReference section */
/* Begin PBXResourcesBuildPhase section */
\t\t$phase /* Resources */ = {
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tfiles = (
${entries.map((entry) => '\t\t\t\t$entry,\n').join()}\t\t\t);
\t\t};
\t\t111111111111111111111111 /* Resources */ = {
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tfiles = (
${testEntries.map((entry) => '\t\t\t\t$entry,\n').join()}\t\t\t);
\t\t};
/* End PBXResourcesBuildPhase section */
/* Begin PBXSourcesBuildPhase section */
\t\tFFFFFFFFFFFFFFFFFFFFFFFF /* Sources */ = {
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tfiles = (
${sources.map((entry) => '\t\t\t\t$entry,\n').join()}\t\t\t);
\t\t};
/* End PBXSourcesBuildPhase section */
''';

    const mEntry = '$mBuild /* M in Resources */';
    const otherEntry = '$otherBuild /* Other in Resources */';

    bool clean(String before, String after) {
      write(golden, pbxproj, before);
      write(actual, pbxproj, after);

      return compareTrees(golden, actual, whitelist: whitelist).isClean;
    }

    test('compares both without what moved, which is the same in both', () {
      expect(
        clean(
          project(entries: [otherEntry, mEntry]),
          project(entries: [mEntry, otherEntry]),
        ),
        isTrue,
      );
    });

    test('does not hide a reference that is gone', () {
      expect(
        clean(
          project(entries: [otherEntry, mEntry]),
          project(entries: [otherEntry], reference: false, build: false),
        ),
        isFalse,
      );
    });

    test('does not hide an entry that is gone from its phase', () {
      expect(
        clean(
          project(entries: [otherEntry, mEntry]),
          project(entries: [otherEntry]),
        ),
        isFalse,
      );
    });

    test('does not hide a reference that changed', () {
      expect(
        clean(
          project(entries: [mEntry]),
          project(entries: [mEntry], path: 'n'),
        ),
        isFalse,
      );
    });

    test('does not hide build files that swap their phases', () {
      const plain = 'AAAA00000000000000000001 /* M in Resources */';
      const signed = 'AAAA00000000000000000002 /* M in Resources */';
      String twoTargets({required bool swapped}) =>
          '''
/* Begin PBXBuildFile section */
\t\tAAAA00000000000000000001 /* M in Resources */ = {isa = PBXBuildFile; fileRef = $m; };
\t\tAAAA00000000000000000002 /* M in Resources */ = {isa = PBXBuildFile; fileRef = $m; settings = {ATTRIBUTES = (CodeSignOnCopy, ); }; };
/* End PBXBuildFile section */
/* Begin PBXFileReference section */
\t\t$m /* M */ = {isa = PBXFileReference; path = m; sourceTree = "<group>"; };
/* End PBXFileReference section */
/* Begin PBXResourcesBuildPhase section */
\t\t$phase /* Resources */ = {
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tfiles = (
\t\t\t\t${swapped ? signed : plain},
\t\t\t);
\t\t};
\t\t111111111111111111111111 /* Resources */ = {
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tfiles = (
\t\t\t\t${swapped ? plain : signed},
\t\t\t);
\t\t};
/* End PBXResourcesBuildPhase section */
''';

      expect(
        clean(twoTargets(swapped: false), twoTargets(swapped: true)),
        isFalse,
      );
      expect(
        clean(twoTargets(swapped: false), twoTargets(swapped: false)),
        isTrue,
      );
    });

    test('does not hide other properties of a build file', () {
      expect(
        clean(
          project(entries: [mEntry]),
          project(entries: [mEntry]).replaceFirst(
            'fileRef = $m; }',
            'fileRef = $m; settings = {ATTRIBUTES = (CodeSignOnCopy, ); }; }',
          ),
        ),
        isFalse,
      );
    });

    test('does not hide a build file that points to another file', () {
      expect(
        clean(
          project(entries: [mEntry]),
          project(entries: [mEntry], buildOf: other),
        ),
        isFalse,
      );
    });

    test(
      'does not hide an entry that is in another phase of the same kind',
      () {
        expect(
          clean(project(entries: [mEntry]), project(testEntries: [mEntry])),
          isFalse,
        );
      },
    );

    test('does not hide an entry that is in another phase', () {
      expect(
        clean(project(entries: [mEntry]), project(sources: [mEntry])),
        isFalse,
      );
    });

    test('does not hide anything else', () {
      expect(
        clean(
          project(entries: [mEntry]),
          project(entries: [mEntry]).replaceAll('path = o', 'path = x'),
        ),
        isFalse,
      );
    });
  });

  group('an only-comments whitelist entry', () {
    final whitelist = Whitelist.parse('''
- path: ios/Runner.xcodeproj/project.pbxproj
  only-comments: true
  reason: Ruby annotates it so
''');
    const pbxproj = 'ios/Runner.xcodeproj/project.pbxproj';

    test('tolerates a file that differs only in its annotations', () {
      write(golden, pbxproj, 'a = B /* Flutter/x.xcconfig */;\nc = D;\n');
      write(actual, pbxproj, 'a = B /* x.xcconfig */;\nc = D /* Runner */;\n');

      final report = compareTrees(golden, actual, whitelist: whitelist);

      expect(report.isClean, isTrue);
      expect(report.differences.single.reason, 'Ruby annotates it so');
    });

    test('does not hide a change beside the annotations', () {
      write(golden, pbxproj, 'a = B /* x */;\nc = D;\n');
      write(actual, pbxproj, 'a = B /* y */;\nc = E;\n');

      final report = compareTrees(golden, actual, whitelist: whitelist);

      expect(report.isClean, isFalse);
      expect(report.differences.single.reason, isNull);
    });

    test('does not hide a change inside a quoted value', () {
      write(golden, pbxproj, 'shellScript = "echo \' /* old */\'";\n');
      write(actual, pbxproj, 'shellScript = "echo \' /* new */\'";\n');

      final report = compareTrees(golden, actual, whitelist: whitelist);

      expect(report.isClean, isFalse);
      expect(report.differences.single.reason, isNull);
    });

    test('does not hide a change after an escaped quote', () {
      write(golden, pbxproj, 'shellScript = "echo \\" /* old */";\n');
      write(actual, pbxproj, 'shellScript = "echo \\" /* new */";\n');

      final report = compareTrees(golden, actual, whitelist: whitelist);

      expect(report.isClean, isFalse);
    });

    test('tolerates annotations around a quoted value that did not change', () {
      write(
        golden,
        pbxproj,
        'a = B /* old */;\nshellScript = "echo \' /* same */\'";\n',
      );
      write(
        actual,
        pbxproj,
        'a = B /* new */;\nshellScript = "echo \' /* same */\'";\n',
      );

      final report = compareTrees(golden, actual, whitelist: whitelist);

      expect(report.isClean, isTrue);
    });

    test('tolerates an annotation that holds quotes', () {
      write(
        golden,
        pbxproj,
        'a = B /* XCLocalSwiftPackageReference "Old" */;\n',
      );
      write(
        actual,
        pbxproj,
        'a = B /* XCLocalSwiftPackageReference "New" */;\n',
      );

      final report = compareTrees(golden, actual, whitelist: whitelist);

      expect(report.isClean, isTrue);
    });

    test('does not hide an added file', () {
      write(actual, pbxproj, 'a = B;\n');

      final report = compareTrees(golden, actual, whitelist: whitelist);

      expect(report.isClean, isFalse);
    });

    test('does not hide a removed file', () {
      write(golden, pbxproj, 'a = B;\n');

      final report = compareTrees(golden, actual, whitelist: whitelist);

      expect(report.isClean, isFalse);
    });
  });

  group('the whitelist of the pbxproj files, as it ships', () {
    // The entries of the real whitelist, not a copy: what they let through is
    // what the parity check lets through.
    final whitelist = Whitelist.parse(
      File('tool/parity/whitelist.yaml').readAsStringSync(),
    );

    /// A project with a reference to each of [files], in a group, and a build
    /// file in the Resources phase for each of [resources]. A file is spelled
    /// as the project spells its path, and the references are the ones
    /// dart_xcodeproj writes: `includeInIndex = 1`, then [type] if it is an
    /// xcconfig, then [extra], then the path.
    ///
    /// The UUIDs are the ones of the normalizer, which names a build file after
    /// its place in the phase: taking one out renames the ones after it.
    String project(
      List<String> files, {
      required List<String> resources,
      String type = '',
      String extra = '',
      Map<String, String> typeOf = const {},
    }) {
      String id(String name) =>
          'F${files.indexOf(name).toString().padLeft(23, '0')}';
      String buildFile(String name) =>
          'B${files.indexOf(name).toString().padLeft(23, '0')}';

      return normalizePbxproj(
        '// !\$*UTF8*\$!\n'
        '{\n'
        '\tobjects = {\n'
        '\n'
        '/* Begin PBXBuildFile section */\n'
        '${resources.map((name) => '\t\t${buildFile(name)} /* $name in Resources */ = '
            '{isa = PBXBuildFile; fileRef = ${id(name)} /* $name */; };\n').join()}'
        '/* End PBXBuildFile section */\n'
        '\n'
        '/* Begin PBXFileReference section */\n'
        '${files.map((name) => '\t\t${id(name)} /* $name */ = '
            '{isa = PBXFileReference; includeInIndex = 1; '
            '${typeOf[name] ?? (name.endsWith('.xcconfig') ? type : '')}'
            '${extra.isEmpty ? '' : '$extra '}'
            'path = ${_quoted(name)}; sourceTree = "<group>"; };\n').join()}'
        '/* End PBXFileReference section */\n'
        '\n'
        '/* Begin PBXGroup section */\n'
        '\t\tAAAAAAAAAAAAAAAAAAAAAAA1 /* Group */ = {\n'
        '\t\t\tisa = PBXGroup;\n'
        '\t\t\tchildren = (\n'
        '${files.map((name) => '\t\t\t\t${id(name)} /* $name */,\n').join()}'
        '\t\t\t);\n'
        '\t\t};\n'
        '/* End PBXGroup section */\n'
        '\n'
        '/* Begin PBXNativeTarget section */\n'
        '\t\tBBBBBBBBBBBBBBBBBBBBBBBB /* Runner */ = {\n'
        '\t\t\tisa = PBXNativeTarget;\n'
        '\t\t\tbuildPhases = (\n'
        '\t\t\t\tCCCCCCCCCCCCCCCCCCCCCCCC /* Resources */,\n'
        '\t\t\t);\n'
        '\t\t};\n'
        '/* End PBXNativeTarget section */\n'
        '\n'
        '/* Begin PBXProject section */\n'
        '\t\tAAAAAAAAAAAAAAAAAAAAAAAA /* Project object */ = {\n'
        '\t\t\tisa = PBXProject;\n'
        '\t\t\tmainGroup = AAAAAAAAAAAAAAAAAAAAAAA1 /* Group */;\n'
        '\t\t\ttargets = (\n'
        '\t\t\t\tBBBBBBBBBBBBBBBBBBBBBBBB /* Runner */,\n'
        '\t\t\t);\n'
        '\t\t};\n'
        '/* End PBXProject section */\n'
        '\n'
        '/* Begin PBXResourcesBuildPhase section */\n'
        '\t\tCCCCCCCCCCCCCCCCCCCCCCCC /* Resources */ = {\n'
        '\t\t\tisa = PBXResourcesBuildPhase;\n'
        '\t\t\tfiles = (\n'
        '${resources.map((name) => '\t\t\t\t${buildFile(name)} /* $name in Resources */,\n').join()}'
        '\t\t\t);\n'
        '\t\t};\n'
        '/* End PBXResourcesBuildPhase section */\n'
        '\t};\n'
        '\trootObject = AAAAAAAAAAAAAAAAAAAAAAAA /* Project object */;\n'
        '}\n',
      );
    }

    const typed = 'lastKnownFileType = text.xcconfig; ';

    test('spell the name of a flavor as the processors take it', () {
      final text = File('tool/parity/whitelist.yaml').readAsStringSync();
      final patterns =
          RegExp(r"^  (?:drop-from-golden|ignore): '(.*)'$", multiLine: true)
              .allMatches(text)
              .map((match) => match.group(1)!)
              .where(
                // The ones about the flavor xcconfigs: the others do not name a flavor.
                (pattern) => pattern.contains('xcconfig'),
              )
              .toList();

      // The two patterns of each of the two projects.
      expect(patterns, hasLength(4));
      for (final pattern in patterns) {
        expect(pattern, contains('$flavorNameCharacter+'));
        expect(
          pattern.replaceAll(flavorNameCharacter, ''),
          isNot(contains('[^')),
          reason: 'a character class of its own is another definition',
        );
      }
    });

    for (final (platform, folder) in [
      ('ios', 'Flutter'),
      ('macos', 'Runner/Configs'),
    ]) {
      group(platform, () {
        final pbxproj = '$platform/Runner.xcodeproj/project.pbxproj';
        final apple = '$folder/appleDebug.xcconfig';
        final banana = '$folder/bananaRelease.xcconfig';
        final overrides = '$folder/UserOverrides.xcconfig';
        const storyboard = 'Runner/Info.storyboard';
        final files = [apple, banana, overrides, storyboard];

        bool clean(String before, String after) {
          write(golden, pbxproj, before);
          write(actual, pbxproj, after);

          return compareTrees(golden, actual, whitelist: whitelist).isClean;
        }

        test('tolerates the flavor xcconfigs that are no resources anymore, '
            'though the entries after them are named again', () {
          expect(
            clean(
              project(files, resources: files),
              project(
                files,
                resources: [overrides, storyboard],
                typeOf: {apple: typed, banana: typed},
              ),
            ),
            isTrue,
          );
        });

        test('keeps the xcconfig of the user in Resources', () {
          final golden = project(files, resources: files);

          // Dropping it is a regression, whatever the rest does.
          expect(
            clean(
              golden,
              project(
                files,
                resources: [storyboard],
                typeOf: {apple: typed, banana: typed},
              ),
            ),
            isFalse,
          );
          expect(
            clean(
              golden,
              project(
                files,
                resources: [],
                typeOf: {apple: typed, banana: typed},
              ),
            ),
            isFalse,
          );
        });

        test('fails when a flavor xcconfig is still a resource', () {
          final golden = project(files, resources: files);

          expect(
            clean(
              golden,
              project(
                files,
                resources: [apple, overrides, storyboard],
                typeOf: {apple: typed, banana: typed},
              ),
            ),
            isFalse,
          );
        });

        test('fails when what is dropped is not a flavor xcconfig', () {
          final golden = project(files, resources: files);

          expect(
            clean(
              golden,
              project(
                files,
                resources: [apple, banana],
                typeOf: {apple: typed, banana: typed},
              ),
            ),
            isFalse,
          );
        });

        test('fails when the xcconfig of a flavor is in another folder', () {
          const other = 'Other/appleDebug.xcconfig';
          final all = [...files, other];

          expect(
            clean(
              project(all, resources: all),
              project(
                all,
                resources: [overrides, storyboard],
                typeOf: {apple: typed, banana: typed},
              ),
            ),
            isFalse,
          );
        });

        test('tolerates the type on the references of the flavors only', () {
          final golden = project(files, resources: [overrides, storyboard]);

          expect(
            clean(
              golden,
              project(
                files,
                resources: [overrides, storyboard],
                typeOf: {apple: typed, banana: typed},
              ),
            ),
            isTrue,
          );
        });

        test('fails when something else gains the type of an xcconfig', () {
          final golden = project(files, resources: [overrides, storyboard]);

          expect(
            clean(
              golden,
              project(
                files,
                resources: [overrides, storyboard],
                typeOf: {apple: typed, banana: typed, storyboard: typed},
              ),
            ),
            isFalse,
          );
          expect(
            clean(
              golden,
              project(
                files,
                resources: [overrides, storyboard],
                typeOf: {apple: typed, banana: typed, overrides: typed},
              ),
            ),
            isFalse,
          );
        });

        test('fails when a flavor reference gains something else', () {
          final golden = project(files, resources: [overrides, storyboard]);

          expect(
            clean(
              golden,
              project(
                files,
                resources: [overrides, storyboard],
                typeOf: {apple: '${typed}fileEncoding = 4; ', banana: typed},
              ),
            ),
            isFalse,
          );
        });

        test('tolerates a flavor that is named with any character a flavor may '
            'have', () {
          for (final name in [
            'my-flavor',
            'my.flavor',
            '1abc',
            'a\$b',
            'a{b}',
            'a#b',
            'a,b',
            'a=b',
          ]) {
            final flavor = '$folder/${name}Debug.xcconfig';
            final all = [flavor, overrides, storyboard];

            expect(
              clean(
                project(all, resources: all),
                project(
                  all,
                  resources: [overrides, storyboard],
                  typeOf: {flavor: typed},
                ),
              ),
              isTrue,
              reason: name,
            );
          }
        });

        test('fails on any other change', () {
          final golden = project(files, resources: files);

          expect(
            clean(
              golden,
              project(
                files,
                resources: [overrides, storyboard],
                typeOf: {apple: typed, banana: typed},
              ).replaceFirst('path = $storyboard;', 'path = Other.storyboard;'),
            ),
            isFalse,
          );
        });
      });
    }
  });

  group('Whitelist.parse', () {
    test('rejects an entry without a reason', () {
      expect(
        () => Whitelist.parse('- path: lib/main.dart\n'),
        throwsFormatException,
      );
    });

    test('rejects an entry with a blank reason', () {
      expect(
        () => Whitelist.parse('- path: lib/main.dart\n  reason: "  "\n'),
        throwsFormatException,
      );
    });
  });
}
