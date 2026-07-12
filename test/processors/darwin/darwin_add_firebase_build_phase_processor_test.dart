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
import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:flutter_flavorizr/src/processors/darwin/darwin_add_firebase_build_phase_processor.dart';
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

  test(
      'Test DarwinAddFirebaseBuildPhaseProcessor adds a Firebase Setup shell script build phase as the first phase',
      () async {
    await TestUtils.withTempDir((dir) async {
      final projectPath = '${dir.path}/Runner.xcodeproj';
      copyPathSync(exampleProjectPath, projectPath);

      final scriptPath = '${dir.path}/firebase.sh';
      File(scriptPath).writeAsStringSync('echo "firebase setup"');

      final processor = DarwinAddFirebaseBuildPhaseProcessor(
        projectPath,
        scriptPath,
        config: flavorizr,
        logger: logger,
      );

      await processor.execute();

      final reopened = await XcodeProject.open(projectPath);
      final target = reopened.targets.first as PBXNativeTarget;

      final firebasePhases = target.buildPhases
          .whereType<PBXShellScriptBuildPhase>()
          .where((phase) => phase.name == 'Firebase Setup')
          .toList();

      expect(firebasePhases, hasLength(1));
      expect(firebasePhases.first.shellScript, 'echo "firebase setup"');
      expect(target.buildPhases.first, same(firebasePhases.first));
    });
  });

  test(
      'Test DarwinAddFirebaseBuildPhaseProcessor replaces an existing Firebase Setup phase instead of duplicating it',
      () async {
    await TestUtils.withTempDir((dir) async {
      final projectPath = '${dir.path}/Runner.xcodeproj';
      copyPathSync(exampleProjectPath, projectPath);

      final scriptPath = '${dir.path}/firebase.sh';
      File(scriptPath).writeAsStringSync('echo "first"');

      await DarwinAddFirebaseBuildPhaseProcessor(
        projectPath,
        scriptPath,
        config: flavorizr,
        logger: logger,
      ).execute();

      File(scriptPath).writeAsStringSync('echo "second"');

      await DarwinAddFirebaseBuildPhaseProcessor(
        projectPath,
        scriptPath,
        config: flavorizr,
        logger: logger,
      ).execute();

      final reopened = await XcodeProject.open(projectPath);
      final target = reopened.targets.first as PBXNativeTarget;
      final firebasePhases = target.buildPhases
          .whereType<PBXShellScriptBuildPhase>()
          .where((phase) => phase.name == 'Firebase Setup')
          .toList();

      expect(firebasePhases, hasLength(1));
      expect(firebasePhases.first.shellScript, 'echo "second"');
    });
  });

  test(
      'Test DarwinAddFirebaseBuildPhaseProcessor throws when the script file is missing',
      () async {
    await TestUtils.withTempDir((dir) async {
      final projectPath = '${dir.path}/Runner.xcodeproj';
      copyPathSync(exampleProjectPath, projectPath);

      final processor = DarwinAddFirebaseBuildPhaseProcessor(
        projectPath,
        '${dir.path}/missing.sh',
        config: flavorizr,
        logger: logger,
      );

      await expectLater(
        processor.execute(),
        throwsA(isA<FileSystemException>()),
      );
    });
  });

}
