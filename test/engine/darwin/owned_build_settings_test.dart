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
import 'package:flutter_flavorizr/src/engine/darwin/owned_build_settings.dart';
import 'package:flutter_flavorizr/src/engine/darwin/owned_objects.dart';
import 'package:flutter_flavorizr/src/engine/flavorizr_context.dart';
import 'package:flutter_flavorizr/src/engine/resources/xcodeproj_resource.dart';
import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

const _pbxproj = XcodeprojResource.iosArtifact;

void main() {
  late Directory temp;
  late XcodeProject project;
  late XCBuildConfiguration config;

  /// The context of a processor that wrote [previous] in the last run.
  FlavorizrContext contextOf([Map<String, String> previous = const {}]) =>
      FlavorizrContext(
        config: FlavorizrConfig.parse(
          'flavors:\n  dev:\n    app:\n      name: dev\n'
          '    ios:\n      bundleId: com.example.dev\n',
        ),
        root: temp,
        projectRoot: temp,
        logger: Logger(level: Level.quiet),
        processorId: 'ios:buildTargets',
        previousKeys: {
          'ios:buildTargets': {_pbxproj.path: previous},
        },
        resources: {XcodeprojResource.iosKey: project},
      );

  OwnedBuildSettings settingsOf(FlavorizrContext ctx) =>
      OwnedBuildSettings(OwnedObjects.ios(ctx));

  String hash(Object? value) => OwnedBuildSettings.hashOf(value);

  setUp(() async {
    temp = Directory.systemTemp.createTempSync('flavorizr_settings_');
    addTearDown(() => temp.deleteSync(recursive: true));

    final bundle = p.join(temp.path, 'ios', 'Runner.xcodeproj');

    Directory(bundle).createSync(recursive: true);
    File(
      'test_resources/example_2x/${_pbxproj.path}',
    ).copySync(p.join(bundle, 'project.pbxproj'));

    project = await XcodeProject.open(bundle);
    config = project.buildConfigurationList['Debug-apple']!;
  });

  group('OwnedBuildSettings.hashOf', () {
    test('is the sha256 of the value, as JSON', () {
      expect(
        hash('5.0'),
        'sha256:5cc31a244d7ddd1ee58e87b2a8426d5f3764ccb41f1f9ab97a96b72b30ebd30c',
      );
    });

    test('tells a list from a string, and one value from another', () {
      expect(hash('5.0'), isNot(hash('5.1')));
      expect(hash(['a']), isNot(hash('a')));
      expect(hash(['a', 'b']), hash(['a', 'b']));
    });
  });

  group('OwnedBuildSettings.apply', () {
    test('sets the settings that are wanted and nothing else', () {
      config.buildSettings = {'DEVELOPMENT_TEAM': 'ABCDE12345'};
      final settings = settingsOf(contextOf());

      settings.apply(
        config,
        scope: OwnedBuildSettings.projectScope,
        wanted: {'SWIFT_VERSION': '5.0', 'PRODUCT_BUNDLE_IDENTIFIER': 'a.b'},
      );

      expect(config.buildSettings, {
        'DEVELOPMENT_TEAM': 'ABCDE12345',
        'SWIFT_VERSION': '5.0',
        'PRODUCT_BUNDLE_IDENTIFIER': 'a.b',
      });
    });

    test('overwrites the value of a setting that is wanted', () {
      config.buildSettings = {'SWIFT_VERSION': '4.2'};

      settingsOf(contextOf()).apply(
        config,
        scope: OwnedBuildSettings.projectScope,
        wanted: {'SWIFT_VERSION': '5.0'},
      );

      expect(config.buildSettings, {'SWIFT_VERSION': '5.0'});
    });

    test('copies a value, so that two configurations share no list', () {
      final other = project.buildConfigurationList['Release-apple']!;
      final wanted = {
        'OTHER_LDFLAGS': ['-ObjC'],
      };
      final settings = settingsOf(contextOf());

      for (final target in [config, other]) {
        settings.apply(
          target,
          scope: OwnedBuildSettings.projectScope,
          wanted: wanted,
        );
      }
      (config.buildSettings['OTHER_LDFLAGS'] as List).add('-all_load');

      expect(other.buildSettings['OTHER_LDFLAGS'], ['-ObjC']);
      expect(wanted['OTHER_LDFLAGS'], ['-ObjC']);
    });
  });

  group('OwnedBuildSettings.settle', () {
    test('tells the context which settings it wrote, by scope and '
        'configuration', () {
      final ctx = contextOf();
      final settings = settingsOf(ctx);

      settings.apply(
        config,
        scope: OwnedBuildSettings.projectScope,
        wanted: {'SWIFT_VERSION': '5.0'},
      );
      final targetConfig = project.newObject<XCBuildConfiguration>(
        (g, u) => XCBuildConfiguration(g, u),
      )..name = 'Debug-apple';

      project.nativeTargets.first.buildConfigurationList!.buildConfigurations
          .add(targetConfig);
      settings.apply(
        targetConfig,
        scope: OwnedBuildSettings.targetScope,
        wanted: {'PRODUCT_NAME': r'$(TARGET_NAME)'},
      );
      final removed = settings.settle();

      expect(removed, isEmpty);
      expect(ctx.ownedKeys, {
        'ios:buildTargets': {
          _pbxproj.path: {
            'project/Debug-apple/SWIFT_VERSION': hash('5.0'),
            'target/Debug-apple/PRODUCT_NAME': hash(r'$(TARGET_NAME)'),
          },
        },
      });
    });

    test('removes a setting that is no longer wanted while it holds what '
        'flavorizr wrote', () {
      config.buildSettings = {
        'SWIFT_VERSION': '5.0',
        'DEVELOPMENT_TEAM': 'ABCDE12345',
      };
      final ctx = contextOf({'project/Debug-apple/SWIFT_VERSION': hash('5.0')});
      final settings = settingsOf(ctx);

      settings.apply(
        config,
        scope: OwnedBuildSettings.projectScope,
        wanted: const {},
      );
      final removed = settings.settle();

      expect(removed, ['project/Debug-apple/SWIFT_VERSION']);
      expect(config.buildSettings, {'DEVELOPMENT_TEAM': 'ABCDE12345'});
      expect(ctx.ownedKeys['ios:buildTargets']![_pbxproj.path], isEmpty);
    });

    test('keeps a setting that is no longer wanted when the value is not the '
        'one flavorizr wrote, and stops owning it', () {
      config.buildSettings = {'SWIFT_VERSION': '6.0'};
      final ctx = contextOf({'project/Debug-apple/SWIFT_VERSION': hash('5.0')});
      final settings = settingsOf(ctx);

      settings.apply(
        config,
        scope: OwnedBuildSettings.projectScope,
        wanted: const {},
      );
      final removed = settings.settle();

      expect(removed, isEmpty);
      expect(config.buildSettings, {'SWIFT_VERSION': '6.0'});
      expect(ctx.ownedKeys['ios:buildTargets']![_pbxproj.path], isEmpty);
    });

    test('keeps a setting that is still wanted', () {
      config.buildSettings = {'SWIFT_VERSION': '5.0'};
      final ctx = contextOf({'project/Debug-apple/SWIFT_VERSION': hash('5.0')});
      final settings = settingsOf(ctx);

      settings.apply(
        config,
        scope: OwnedBuildSettings.projectScope,
        wanted: {'SWIFT_VERSION': '5.0'},
      );

      expect(settings.settle(), isEmpty);
      expect(config.buildSettings, {'SWIFT_VERSION': '5.0'});
    });

    test('removes the settings of a flavor that is gone, in the '
        'configuration that is still there', () {
      config.buildSettings = {
        'SWIFT_VERSION': '5.0',
        'DEVELOPMENT_TEAM': 'ABCDE12345',
      };
      final ctx = contextOf({'project/Debug-apple/SWIFT_VERSION': hash('5.0')});

      // `apply` is never called for it: the flavor is not wanted anymore.
      final removed = settingsOf(ctx).settle();

      expect(removed, ['project/Debug-apple/SWIFT_VERSION']);
      expect(config.buildSettings, {'DEVELOPMENT_TEAM': 'ABCDE12345'});
    });

    test('forgets the settings of a configuration that is not there', () {
      final ctx = contextOf({
        'project/Debug-gone/SWIFT_VERSION': hash('5.0'),
        'target/Debug-gone/PRODUCT_NAME': hash('x'),
      });
      final settings = settingsOf(ctx);

      expect(settings.settle(), isEmpty);
      expect(ctx.ownedKeys['ios:buildTargets']![_pbxproj.path], isEmpty);
    });

    test('forgets a key it cannot read, instead of guessing', () {
      final ctx = contextOf({'not a key': hash('x')});

      expect(settingsOf(ctx).settle(), isEmpty);
    });

    test('removes a setting by the name it has, brackets and slashes '
        'included', () {
      const name = 'CODE_SIGN_IDENTITY[sdk=iphoneos*]';

      config.buildSettings = {name: 'Apple Distribution'};
      final ctx = contextOf({
        'project/Debug-apple/$name': hash('Apple Distribution'),
      });

      expect(settingsOf(ctx).settle(), ['project/Debug-apple/$name']);
      expect(config.buildSettings, isEmpty);
    });
  });
}
