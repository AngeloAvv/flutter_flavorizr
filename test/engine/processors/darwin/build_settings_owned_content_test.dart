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

import 'package:dart_xcodeproj/dart_xcodeproj.dart';
import 'package:flutter_flavorizr/src/engine/processors/darwin/build_settings_owned_content.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// The iOS project 2.x flavorized, with a `Debug-apple` configuration in the
/// first target too (which 2.x made, with its `DEVELOPMENT_TEAM` wiped, and
/// Xcode puts back), and one in `RunnerTests`.
late String _source;

String _edit(String source, String from, String to) {
  expect(source, contains(from), reason: 'the project has no `$from`');

  return source.replaceFirst(from, to);
}

void main() {
  late Directory temp;

  setUpAll(() async {
    temp = Directory.systemTemp.createTempSync('flavorizr_owned_content_');

    final bundle = p.join(temp.path, 'Runner.xcodeproj');

    Directory(bundle).createSync(recursive: true);
    File(
      'test_resources/example_2x/ios/Runner.xcodeproj/project.pbxproj',
    ).copySync(p.join(bundle, 'project.pbxproj'));

    final project = await XcodeProject.open(bundle);

    for (final target in project.nativeTargets) {
      final config = project.newObject<XCBuildConfiguration>(
        (g, u) => XCBuildConfiguration(g, u),
      );

      config.name = 'Debug-apple';
      config.buildSettings = {
        'PRODUCT_NAME': target.name == 'Runner'
            ? r'$(TARGET_NAME)'
            : 'TestsName',
        'DEVELOPMENT_TEAM': 'ABCDE12345',
      };
      target.buildConfigurationList!.buildConfigurations.add(config);
    }

    await project.save();

    _source = File(p.join(bundle, 'project.pbxproj')).readAsStringSync();
  });

  tearDownAll(() => temp.deleteSync(recursive: true));

  group('buildSettingsOwnedContent', () {
    test('is what the flavor configurations of the project and the '
        'product name of the target say', () {
      final owned = buildSettingsOwnedContent(_source);

      expect(owned, contains('project/Debug-apple/SWIFT_VERSION'));
      expect(
        owned,
        contains('project/Release-banana/PRODUCT_BUNDLE_IDENTIFIER'),
      );
      expect(owned, contains('target/Debug-apple/PRODUCT_NAME'));
    });

    test('is empty for a project that has no flavor configuration', () {
      final source = _source.replaceAll(
        RegExp(r'name = "?(Debug|Profile|Release)-(apple|banana)"?;'),
        'name = Other;',
      );

      expect(buildSettingsOwnedContent(source), isEmpty);
    });

    test('is the same for a project that is written again the same', () {
      expect(
        buildSettingsOwnedContent(_source),
        buildSettingsOwnedContent(_source),
      );
      expect(
        buildSettingsOwnedContent(_source.replaceAll('\n', '\r\n')),
        buildSettingsOwnedContent(_source),
      );
    });

    test('changes when an owned setting of a flavor changes', () {
      final edited = _edit(
        _source,
        'SWIFT_VERSION = 5.0;',
        'SWIFT_VERSION = 6.0;',
      );

      expect(
        buildSettingsOwnedContent(edited),
        isNot(buildSettingsOwnedContent(_source)),
      );
    });

    test('changes when the product name of a flavor target changes', () {
      final edited = _source.replaceAll(
        r'PRODUCT_NAME = "$(TARGET_NAME)";',
        'PRODUCT_NAME = Mine;',
      );

      expect(edited, isNot(_source));
      expect(
        buildSettingsOwnedContent(edited),
        isNot(buildSettingsOwnedContent(_source)),
      );
    });

    test('changes when a setting is added to the configuration of a '
        'flavor', () {
      final edited = _edit(
        _source,
        'SWIFT_VERSION = 5.0;',
        'SWIFT_VERSION = 5.0;\n\t\t\t\tZZZ = 1;',
      );

      expect(
        buildSettingsOwnedContent(edited),
        isNot(buildSettingsOwnedContent(_source)),
      );
    });

    test('is not changed by the settings of the target that are not '
        'flavorizr\'s', () {
      final edited = _edit(
        _source,
        'DEVELOPMENT_TEAM = ABCDE12345;',
        'DEVELOPMENT_TEAM = FGHIJ67890;',
      );

      expect(edited, isNot(_source));
      expect(
        buildSettingsOwnedContent(edited),
        buildSettingsOwnedContent(_source),
      );
    });

    test('is not changed by the product name of another target', () {
      final edited = _edit(
        _source,
        'PRODUCT_NAME = TestsName;',
        'PRODUCT_NAME = Other;',
      );

      expect(
        buildSettingsOwnedContent(edited),
        buildSettingsOwnedContent(_source),
      );
    });

    test('is not changed by the configurations that are not a flavor\'s', () {
      // `Profile` of the project, which comes before the flavor ones.
      final start = _source.indexOf('/* Profile */ = {');
      final edited =
          _source.substring(0, start) +
          _edit(
            _source.substring(start),
            'SDKROOT = iphoneos;',
            'SDKROOT = macosx;',
          );

      expect(edited, isNot(_source));
      expect(
        buildSettingsOwnedContent(edited),
        buildSettingsOwnedContent(_source),
      );
    });

    test('is not changed by the rest of the project', () {
      final edited = _edit(
        _source,
        'defaultConfigurationName = Release;',
        'defaultConfigurationName = Debug;',
      );

      expect(
        buildSettingsOwnedContent(edited),
        buildSettingsOwnedContent(_source),
      );
    });

    test('is empty for a text that is no project', () {
      expect(buildSettingsOwnedContent(''), isEmpty);
      expect(buildSettingsOwnedContent('not a project\n'), isEmpty);
    });
  });
}
