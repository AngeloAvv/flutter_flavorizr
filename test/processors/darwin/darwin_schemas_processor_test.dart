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
import 'package:flutter_flavorizr/src/processors/darwin/darwin_schemas_processor.dart';
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

  test('Test DarwinSchemasProcessor queues one DarwinCreateSchemeProcessor per flavor', () {
    final processor = DarwinSchemasProcessor(
      'project.xcodeproj',
      flavors: flavorizr.iosFlavors,
      config: flavorizr,
      logger: logger,
    );

    expect(processor.processors.length, flavorizr.iosFlavors.length);
    expect(processor.processors, everyElement(isA<DarwinCreateSchemeProcessor>()));
  });

  test('Test DarwinSchemasProcessor creates a scheme file for every flavor when executed',
      () async {
    await TestUtils.withTempDir((dir) async {
      final projectPath = '${dir.path}/Runner.xcodeproj';
      copyPathSync(exampleProjectPath, projectPath);

      final processor = DarwinSchemasProcessor(
        projectPath,
        flavors: flavorizr.iosFlavors,
        config: flavorizr,
        logger: logger,
      );

      await processor.execute();

      for (final flavorName in flavorizr.iosFlavors.keys) {
        expect(
          File('$projectPath/xcshareddata/xcschemes/$flavorName.xcscheme')
              .existsSync(),
          isTrue,
        );
      }
    });
  });

  test(
      'Test DarwinSchemasProcessor skips flavors without an iOS configuration',
      () {
    final mixedConfig = TestUtils.parseFlavorizr(
      'test_resources/darwin/schemas_processor_test/mixed_platforms_pubspec',
    );

    expect(
      mixedConfig.flavors.keys,
      containsAll(<String>['cherry', 'date', 'elderberry']),
    );
    expect(mixedConfig.iosFlavors.keys, <String>['cherry']);

    final processor = DarwinSchemasProcessor(
      'project.xcodeproj',
      flavors: mixedConfig.iosFlavors,
      config: mixedConfig,
      logger: logger,
    );

    expect(processor.processors.length, 1);
    expect(
      (processor.processors.single as DarwinCreateSchemeProcessor).schemeName,
      'cherry',
    );
  });

  test(
      'Test DarwinSchemasProcessor creates no iOS scheme for a flavor without an iOS configuration',
      () async {
    await TestUtils.withTempDir((dir) async {
      final projectPath = '${dir.path}/Runner.xcodeproj';
      copyPathSync(exampleProjectPath, projectPath);

      final mixedConfig = TestUtils.parseFlavorizr(
        'test_resources/darwin/schemas_processor_test/mixed_platforms_pubspec',
      );

      final processor = DarwinSchemasProcessor(
        projectPath,
        flavors: mixedConfig.iosFlavors,
        config: mixedConfig,
        logger: logger,
      );

      await processor.execute();

      expect(
        File('$projectPath/xcshareddata/xcschemes/cherry.xcscheme').existsSync(),
        isTrue,
      );
      expect(
        File('$projectPath/xcshareddata/xcschemes/date.xcscheme').existsSync(),
        isFalse,
      );
      expect(
        File('$projectPath/xcshareddata/xcschemes/elderberry.xcscheme')
            .existsSync(),
        isFalse,
      );
    });
  });

  test(
      'Test DarwinSchemasProcessor creates no macOS scheme for a flavor without a macOS configuration',
      () async {
    await TestUtils.withTempDir((dir) async {
      final projectPath = '${dir.path}/Runner.xcodeproj';
      copyPathSync(exampleProjectPath, projectPath);

      final mixedConfig = TestUtils.parseFlavorizr(
        'test_resources/darwin/schemas_processor_test/mixed_platforms_pubspec',
      );

      expect(mixedConfig.macosFlavors.keys, <String>['elderberry']);

      final processor = DarwinSchemasProcessor(
        projectPath,
        flavors: mixedConfig.macosFlavors,
        config: mixedConfig,
        logger: logger,
      );

      await processor.execute();

      expect(
        File('$projectPath/xcshareddata/xcschemes/elderberry.xcscheme')
            .existsSync(),
        isTrue,
      );
      expect(
        File('$projectPath/xcshareddata/xcschemes/cherry.xcscheme').existsSync(),
        isFalse,
      );
      expect(
        File('$projectPath/xcshareddata/xcschemes/date.xcscheme').existsSync(),
        isFalse,
      );
    });
  });
}
