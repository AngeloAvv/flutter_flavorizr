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

import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:flutter_flavorizr/src/processors/macos/google/firebase/macos_targets_firebase_processor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

import '../../../../test_utils.dart';

void main() {
  late Flavorizr flavorizr;
  late Logger logger;

  setUp(() {
    logger = TestUtils.quietLogger();
    flavorizr = TestUtils.parseFlavorizr(
      'test_resources/macos/targets_firebase_processor_test/pubspec',
    );
  });

  test(
      'MacOSTargetsFirebaseProcessor.execute copies the GoogleService-Info.plist for every firebase-enabled macOS flavor, generates the firebase script, and registers files in the Xcode project',
      () {
    TestUtils.withTempDir((dir) async {
      final projectSourceDir = Directory(
          'test_resources/macos/targets_firebase_processor_test/Runner.xcodeproj');
      final projectDestDir =
          Directory(p.join(dir.path, 'Runner.xcodeproj'))..createSync();

      for (final entity in projectSourceDir.listSync()) {
        if (entity is File) {
          entity.copySync(
              p.join(projectDestDir.path, p.basename(entity.path)));
        }
      }

      final destination = p.join(dir.path, 'Runner');
      Directory(destination).createSync(recursive: true);

      final scriptPath = p.join(dir.path, 'firebaseScript.sh');

      final processor = MacOSTargetsFirebaseProcessor(
        destination: destination,
        runnerProject: projectDestDir.path,
        generatedFirebaseScriptPath: scriptPath,
        config: flavorizr,
        logger: logger,
      );

      await processor.execute();

      expect(
        File(p.join(destination, 'apple', 'GoogleService-Info.plist'))
            .existsSync(),
        isTrue,
      );
      expect(
        File(p.join(destination, 'GoogleService-Info.plist')).existsSync(),
        isTrue,
      );
      expect(File(scriptPath).existsSync(), isTrue);
    });
  });
}
