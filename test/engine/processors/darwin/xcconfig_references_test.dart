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

import 'package:dart_xcodeproj/dart_xcodeproj.dart';
import 'package:flutter_flavorizr/src/engine/processors/darwin/xcconfig_references.dart';
import 'package:flutter_flavorizr/src/processors/darwin/darwin_add_file_processor.dart';
import 'package:flutter_test/flutter_test.dart';

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

void main() {
  group('the reference to a flavor xcconfig', () {
    late XcodeProject project;

    setUp(() async => project = await XcodeProject.open(_ios));

    PBXGroup flutterGroup() =>
        project.groups.firstWhere((group) => group.name == 'Flutter');

    test('is a text xcconfig in the group it is asked for', () {
      final reference = addXcconfigReference(
        project,
        'Flutter/citrusDebug.xcconfig',
        groupName: 'Flutter',
      );

      expect(reference.path, 'Flutter/citrusDebug.xcconfig');
      expect(reference.sourceTree, '<group>');
      expect(reference.lastKnownFileType, 'text.xcconfig');
      expect(flutterGroup().children, contains(reference));
    });

    test('goes in the main group when no group is asked for', () {
      final reference = addXcconfigReference(
        project,
        'Runner/Configs/citrusDebug.xcconfig',
      );

      expect(project.mainGroup.children, contains(reference));
    });

    test('is not in any build phase, Resources included', () {
      final before = _buildFiles(project).length;

      final reference = addXcconfigReference(
        project,
        'Flutter/citrusDebug.xcconfig',
        groupName: 'Flutter',
      );

      expect(_buildFiles(project).length, before);
      expect(
        _buildFiles(project).where((file) => file.fileRef == reference),
        isEmpty,
      );
    });

    test('is found again, not added twice', () {
      final first = addXcconfigReference(
        project,
        'Flutter/citrusDebug.xcconfig',
        groupName: 'Flutter',
      );
      final model = project.toHash();

      final second = addXcconfigReference(
        project,
        'Flutter/citrusDebug.xcconfig',
        groupName: 'Flutter',
      );

      expect(second, same(first));
      expect(project.toHash(), model);
    });

    test('is taken out of Resources when 2.x put it there, and nothing else '
        'is', () {
      // The example was flavorized by 2.x: its xcconfigs are resources.
      final all = _buildFiles(project).length;
      final names = [
        for (final flavor in ['apple', 'banana'])
          for (final target in ['Debug', 'Profile', 'Release'])
            'Flutter/$flavor$target.xcconfig',
      ];
      expect(_xcconfigResources(project), unorderedEquals(names));

      for (final name in names) {
        addXcconfigReference(project, name, groupName: 'Flutter');
      }

      expect(_xcconfigResources(project), isEmpty);
      expect(_buildFiles(project).length, all - names.length);
    });

    test('is left alone in a Resources phase when it is not a flavor one', () {
      // Which is every xcconfig that `addXcconfigReference` is not asked for.
      DarwinAddFileProcessor.addTo(
        project,
        'Flutter/mine.xcconfig',
        groupName: 'Flutter',
      );

      addXcconfigReference(
        project,
        'Flutter/appleDebug.xcconfig',
        groupName: 'Flutter',
      );

      expect(_xcconfigResources(project), contains('Flutter/mine.xcconfig'));
      expect(
        _xcconfigResources(project),
        isNot(contains('Flutter/appleDebug.xcconfig')),
      );
    });

    test('gets the type a 2.x reference lacked', () {
      final existing = flutterGroup().children
          .whereType<PBXFileReference>()
          .firstWhere((file) => file.path == 'Flutter/appleDebug.xcconfig');
      existing.lastKnownFileType = null;

      final again = addXcconfigReference(
        project,
        'Flutter/appleDebug.xcconfig',
        groupName: 'Flutter',
      );

      expect(again, same(existing));
      expect(again.lastKnownFileType, 'text.xcconfig');
    });

    test('is in the project of macOS as well', () async {
      final macos = await XcodeProject.open(_macos);

      final reference = addXcconfigReference(
        macos,
        'Runner/Configs/citrusDebug.xcconfig',
      );

      expect(macos.mainGroup.children, contains(reference));
      expect(
        _xcconfigResources(macos),
        isNot(contains('Runner/Configs/citrusDebug.xcconfig')),
      );
    });

    test('fails with a message when the group does not exist', () {
      expect(
        () => addXcconfigReference(
          project,
          'Flutter/citrusDebug.xcconfig',
          groupName: 'Nope',
        ),
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

  group('what the lock hashes of a project', () {
    String line(String path, {String? type = 'text.xcconfig'}) =>
        '\t\tAAAA /* $path */ = {isa = PBXFileReference; '
        '${type == null ? '' : 'lastKnownFileType = $type; '}'
        'path = $path; sourceTree = "<group>"; };';

    const other = '\t\tBBBB /* Runner */ = {isa = PBXGroup; name = Runner; };';

    test('are the references to the flavor xcconfigs of both platforms', () {
      final source = [
        'before',
        line('Flutter/appleDebug.xcconfig'),
        other,
        line('Runner/Configs/bananaRelease.xcconfig', type: null),
        line('"Flutter/my-flavorProfile.xcconfig"'),
        'after',
      ].join('\n');

      expect(
        xcconfigReferencesOwnedContent(source),
        [
          line('Flutter/appleDebug.xcconfig'),
          line('Runner/Configs/bananaRelease.xcconfig', type: null),
          line('"Flutter/my-flavorProfile.xcconfig"'),
        ].join('\n'),
      );
    });

    test('are the entries of the Resources phase that 2.x added for them', () {
      final definition =
          '\t\tCCCC /* Flutter/appleDebug.xcconfig in Resources */ = '
          '{isa = PBXBuildFile; fileRef = AAAA /* appleDebug.xcconfig */; };';
      final listing = '\t\t\t\tCCCC /* appleDebug.xcconfig in Resources */,';
      final source = [
        '\t\tDDDD /* Assets.xcassets in Resources */ = {isa = PBXBuildFile; };',
        definition,
        '\t\t\t\tDDDD /* Assets.xcassets in Resources */,',
        listing,
        '\t\t\t\tEEEE /* Debug.xcconfig in Resources */,',
      ].join('\n');

      expect(
        xcconfigReferencesOwnedContent(source),
        [definition, listing].join('\n'),
      );
    });

    test('are not the xcconfigs of Flutter or of the user', () {
      final source = [
        line('Flutter/Debug.xcconfig'),
        line('Flutter/Release.xcconfig'),
        line('Debug.xcconfig'),
        line('Flutter-Debug.xcconfig'),
        line('Runner/Configs/AppInfo.xcconfig'),
        line('Other/appleDebug.xcconfig'),
      ].join('\n');

      expect(xcconfigReferencesOwnedContent(source), isEmpty);
    });

    test('do not change when the rest of the project does', () {
      String source(String upgrade) => [
        'LastUpgradeCheck = $upgrade;',
        line('Flutter/appleDebug.xcconfig'),
      ].join('\n');

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

      expect(
        xcconfigReferencesOwnedContent(lines.join('\r\n')),
        xcconfigReferencesOwnedContent(lines.join('\n')),
      );
    });
  });
}
