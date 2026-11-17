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

import 'package:dart_xcodeproj/dart_xcodeproj.dart';
import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:flutter_flavorizr/src/processors/darwin/darwin_add_file_processor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:io/io.dart';
import 'package:mason_logger/mason_logger.dart';

import '../../test_utils.dart';

void main() {
  late Flavorizr flavorizr;
  late Logger logger;

  const exampleProjectPath = 'example/ios/Runner.xcodeproj';

  setUp(() {
    logger = TestUtils.quietLogger();
    flavorizr = TestUtils.parseFlavorizr('test_resources/pubspec');
  });

  test('Test DarwinAddFileProcessor adds a new file reference to the main group',
      () async {
    await TestUtils.withTempDir((dir) async {
      final projectPath = '${dir.path}/Runner.xcodeproj';
      copyPathSync(exampleProjectPath, projectPath);

      final processor = DarwinAddFileProcessor(
        projectPath,
        'Runner/new_asset.txt',
        config: flavorizr,
        logger: logger,
      );

      await processor.execute();

      final reopened = await XcodeProject.open(projectPath);
      expect(
        reopened.files.any((f) => f.path == 'Runner/new_asset.txt'),
        isTrue,
      );
    });
  });

  test(
      'Test DarwinAddFileProcessor.addTo adds the file to the resources of the '
      'first native target, and tells whether it added anything', () async {
    final project = await XcodeProject.open(exampleProjectPath);
    final target = project.targets.first as PBXNativeTarget;
    List<String?> resources() => [
          for (final buildFile in target.resourcesBuildPhase.files)
            if (buildFile.fileRef case final PBXFileReference ref) ref.path,
        ];

    expect(resources(), isNot(contains('Runner/new_asset.txt')));
    expect(
      DarwinAddFileProcessor.addTo(project, 'Runner/new_asset.txt'),
      isTrue,
    );
    expect(
      resources().where((path) => path == 'Runner/new_asset.txt'),
      hasLength(1),
    );
    expect(
      project.mainGroup.children
          .whereType<PBXFileReference>()
          .where((file) => file.path == 'Runner/new_asset.txt'),
      hasLength(1),
    );
    expect(
      DarwinAddFileProcessor.addTo(project, 'Runner/new_asset.txt'),
      isFalse,
    );
    expect(
      resources().where((path) => path == 'Runner/new_asset.txt'),
      hasLength(1),
    );
  });

  test('Test DarwinAddFileProcessor is idempotent when file already added',
      () async {
    await TestUtils.withTempDir((dir) async {
      final projectPath = '${dir.path}/Runner.xcodeproj';
      copyPathSync(exampleProjectPath, projectPath);

      final processor = DarwinAddFileProcessor(
        projectPath,
        'Runner/new_asset.txt',
        config: flavorizr,
        logger: logger,
      );

      await processor.execute();

      final project = await XcodeProject.open(projectPath);
      final countAfterFirstRun =
          project.files.where((f) => f.path == 'Runner/new_asset.txt').length;

      final secondProcessor = DarwinAddFileProcessor(
        projectPath,
        'Runner/new_asset.txt',
        config: flavorizr,
        logger: logger,
      );
      await secondProcessor.execute();

      final reopened = await XcodeProject.open(projectPath);
      final countAfterSecondRun = reopened.files
          .where((f) => f.path == 'Runner/new_asset.txt')
          .length;

      expect(countAfterFirstRun, 1);
      expect(countAfterSecondRun, 1);
    });
  });

}
