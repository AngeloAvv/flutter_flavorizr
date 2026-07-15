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
import 'package:flutter_flavorizr/src/processors/darwin/darwin_create_scheme_processor.dart';
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
      'Test DarwinCreateSchemeProcessor writes an xcscheme file with the flavor build configurations',
      () async {
    await TestUtils.withTempDir((dir) async {
      final projectPath = '${dir.path}/Runner.xcodeproj';
      copyPathSync(exampleProjectPath, projectPath);

      final processor = DarwinCreateSchemeProcessor(
        projectPath,
        'orange',
        config: flavorizr,
        logger: logger,
      );

      await processor.execute();

      final schemeFile =
          File('$projectPath/xcshareddata/xcschemes/orange.xcscheme');
      expect(schemeFile.existsSync(), isTrue);

      final content = schemeFile.readAsStringSync();
      expect(content, contains('Debug-orange'));
      expect(content, contains('Release-orange'));
      expect(content, contains('Profile-orange'));

      final profileActionMatch = RegExp(
        r'<ProfileAction[\s\S]*?</ProfileAction>',
      ).firstMatch(content);
      expect(profileActionMatch, isNotNull);
      expect(
        profileActionMatch!.group(0),
        contains('BuildableProductRunnable'),
      );

      final testActionMatch = RegExp(
        r'<TestAction[\s\S]*?</TestAction>',
      ).firstMatch(content);
      expect(testActionMatch, isNotNull);
      expect(testActionMatch!.group(0), contains('MacroExpansion'));
    });
  });

}
