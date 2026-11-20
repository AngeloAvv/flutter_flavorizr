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
import 'package:flutter_flavorizr/src/engine/resources/xcodeproj_file_reference.dart';
import 'package:test/test.dart';

void main() {
  const exampleProjectPath = 'test_resources/example_2x/ios/Runner.xcodeproj';

  late XcodeProject project;
  late PBXNativeTarget target;

  List<String?> resources() => [
    for (final buildFile in target.resourcesBuildPhase.files)
      if (buildFile.fileRef case final PBXFileReference ref) ref.path,
  ];

  setUp(() async {
    project = await XcodeProject.open(exampleProjectPath);
    target = project.targets.first as PBXNativeTarget;
  });

  group('addFileToProject', () {
    test('adds the file to the main group and to the resources of the first '
        'target, and says it added it', () {
      expect(resources(), isNot(contains('Runner/new_asset.txt')));
      expect(addFileToProject(project, 'Runner/new_asset.txt'), isTrue);
      expect(
        resources().where((path) => path == 'Runner/new_asset.txt'),
        hasLength(1),
      );
      expect(
        project.mainGroup.children.whereType<PBXFileReference>().where(
          (file) => file.path == 'Runner/new_asset.txt',
        ),
        hasLength(1),
      );
    });

    test('does nothing when the group has the file already', () {
      addFileToProject(project, 'Runner/new_asset.txt');

      expect(addFileToProject(project, 'Runner/new_asset.txt'), isFalse);
      expect(
        resources().where((path) => path == 'Runner/new_asset.txt'),
        hasLength(1),
      );
    });

    test('adds the file to the group that was named', () {
      final group = project.groups.firstWhere((g) => g.name != null);

      expect(
        addFileToProject(project, 'new_asset.txt', groupName: group.name),
        isTrue,
      );
      expect(
        group.children.whereType<PBXFileReference>().where(
          (file) => file.path == 'new_asset.txt',
        ),
        hasLength(1),
      );
    });

    test('fails for a group the project does not have', () {
      expect(
        () => addFileToProject(project, 'a.txt', groupName: 'Nope'),
        throwsStateError,
      );
    });
  });
}
