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

import 'dart:convert';

import 'package:flutter_flavorizr/src/engine/artifact.dart';
import 'package:flutter_flavorizr/src/engine/flavorizr_context.dart';
import 'package:flutter_flavorizr/src/engine/flavorizr_processor.dart';
import 'package:flutter_flavorizr/src/engine/resource_key.dart';
import 'package:flutter_flavorizr/src/engine/resources/xcodeproj_resource.dart';
import 'package:flutter_flavorizr/src/engine/shadow/file_digest.dart';
import 'package:flutter_flavorizr/src/entrypoint/processor_registry.dart';
import 'package:flutter_test/flutter_test.dart';

const _manifest = 'android/app/src/main/AndroidManifest.xml';
const _build = 'android/app/build.gradle';

String _manifestWith(String label, {String extra = ''}) =>
    '<manifest>\n<application android:label="$label">$extra</application>\n'
    '</manifest>\n';

List<int> _bytes(String text) => utf8.encode(text);

class _Consumer extends FlavorizrProcessor {
  @override
  final String id;

  final ResourceKey<Object?>? key;

  const _Consumer(this.id, this.key);

  @override
  Set<ResourceKey<Object?>> get requires => {?key};

  @override
  Future<void> apply(FlavorizrContext ctx) async {}
}

void main() {
  final registry = ProcessorRegistry.standard();

  group('ProcessorRegistry', () {
    test('runs the ported Android, Linux, Flutter and xcconfig processors on '
        'the '
        'engine', () {
      expect(registry.engineIds, {
        'android:androidManifest',
        'android:flavorizrGradle',
        'android:buildGradle',
        'android:icons',
        'linux:cmake',
        'linux:runnerCmake',
        'linux:myApplication',
        'ios:xcconfig',
        'macos:xcconfig',
        'macos:configs',
        'flutter:flavors',
        'flutter:pages',
        'flutter:app',
        'flutter:main',
      });
    });

    test('registers the shared Xcode projects of both platforms', () {
      expect(registry.resources.map((resource) => resource.key), {
        XcodeprojResource.iosKey,
        XcodeprojResource.macosKey,
      });
    });

    test('adds the project of a resource to the paths of its consumers', () {
      final custom = ProcessorRegistry(
        engine: [
          const EngineProcessor(
            _Consumer('test:ios', XcodeprojResource.iosKey),
            paths: {'a'},
          ),
          const EngineProcessor(_Consumer('test:none', null), paths: {'b'}),
        ],
        resources: [
          EngineResource(
            XcodeprojResource.ios(),
            paths: {XcodeprojResource.iosProject},
          ),
          EngineResource(
            XcodeprojResource.macos(),
            paths: {XcodeprojResource.macosProject},
          ),
        ],
      );

      expect(custom.pathsOf([custom.engineProcessors['test:ios']!]), {
        'a',
        XcodeprojResource.iosProject,
      });
      expect(custom.pathsOf([custom.engineProcessors['test:none']!]), {'b'});
    });

    test(
      'a full run is the one of the `all` recipe, which has no scaffold',
      () {
        expect(registry.fullRunIds, {
          'android:androidManifest',
          'android:flavorizrGradle',
          'android:buildGradle',
          'android:icons',
          'linux:cmake',
          'linux:runnerCmake',
          'linux:myApplication',
          'ios:xcconfig',
          'macos:xcconfig',
          'macos:configs',
          'flutter:flavors',
        });
      },
    );

    test('hashes the owned part of a file that a resource registers', () {
      final custom = ProcessorRegistry(
        resources: [
          EngineResource(
            XcodeprojResource.ios(),
            ownedContent: {
              XcodeprojResource.iosArtifact.path: (source) =>
                  source.split('\n').first,
            },
          ),
        ],
      );
      final path = XcodeprojResource.iosArtifact.path;

      expect(
        custom.hash(
          XcodeprojResource.iosArtifact,
          _bytes('mine\nxcode wrote this'),
        ),
        custom.hash(XcodeprojResource.iosArtifact, _bytes('mine\nother')),
      );
      expect(
        custom.hash(XcodeprojResource.iosArtifact, _bytes('mine\nx')),
        isNot(custom.hash(XcodeprojResource.iosArtifact, _bytes('yours\nx'))),
      );
      expect(path, 'ios/Runner.xcodeproj/project.pbxproj');
    });

    group('hashes of an Xcode project only', () {
      String reference(String path) =>
          '\t\tA /* x */ = {isa = PBXFileReference; path = $path; };';

      for (final (artifact, path) in [
        (XcodeprojResource.iosArtifact, 'Flutter/appleDebug.xcconfig'),
        (XcodeprojResource.macosArtifact, 'Runner/Configs/appleDebug.xcconfig'),
      ]) {
        test(
          'the references to the xcconfigs of the flavors of ${artifact.path}',
          () {
            final project = 'LastUpgradeCheck = 1510;\n${reference(path)}';

            expect(
              registry.hash(artifact, _bytes(project)),
              registry.hash(
                artifact,
                _bytes(project.replaceAll('1510', '1600')),
              ),
            );
            expect(
              registry.hash(artifact, _bytes(project)),
              isNot(
                registry.hash(
                  artifact,
                  _bytes(project.replaceAll('appleDebug', 'bananaDebug')),
                ),
              ),
            );
          },
        );
      }
    });

    test('keeps every other 2.x instruction on the legacy pipeline', () {
      expect(registry.legacyIds, contains('google:firebase'));
      expect(registry.legacyIds, contains('ios:podfile'));
      expect(registry.legacyIds, contains('android:dummyAssets'));
      expect(registry.legacyIds, contains('windows:cmake'));
      expect(registry.legacyIds, isNot(contains('linux:cmake')));
      expect(registry.legacyIds, isNot(contains('linux:runnerCmake')));
      expect(registry.legacyIds, isNot(contains('linux:myApplication')));
      expect(registry.legacyIds, isNot(contains('android:icons')));
      expect(
        registry.ids,
        hasLength(registry.engineIds.length + registry.legacyIds.length),
      );
    });

    test('a processor that is ported leaves the legacy ones', () {
      final custom = ProcessorRegistry(
        engine: [
          registry.engineProcessors.values.first,
        ].map((processor) => EngineProcessor(processor, paths: {'x'})),
        legacyIds: ['android:androidManifest', 'other'],
      );

      expect(custom.legacyIds, {'other'});
    });

    test('hashes a managed file whole', () {
      expect(
        registry.hash(const Artifact.managed('x'), _bytes('abc')),
        digestOf(_bytes('abc')),
      );
    });

    test('hashes only the label of a manifest', () {
      final a = registry.hash(
        const Artifact.patched(_manifest),
        _bytes(_manifestWith('@string/app_name')),
      );
      final b = registry.hash(
        const Artifact.patched(_manifest),
        _bytes(_manifestWith('@string/app_name', extra: '<!-- mine -->')),
      );
      final c = registry.hash(
        const Artifact.patched(_manifest),
        _bytes(_manifestWith('other')),
      );

      expect(a, b);
      expect(a, isNot(c));
    });

    test('hashes only the region of a build file, whatever the BOM', () {
      const region =
          '// ----- BEGIN flavorDimensions (autogenerated by flutter_flavorizr) -----\n'
          'apply from: "flavorizr.gradle"\n'
          '// ----- END flavorDimensions (autogenerated by flutter_flavorizr) -----\n';

      final plain = registry.hash(
        const Artifact.patched(_build),
        _bytes('android {\n}\n$region'),
      );
      final edited = registry.hash(
        const Artifact.patched(_build),
        _bytes('﻿android {\n  // mine\n}\n$region'),
      );

      expect(plain, edited);
    });

    test('hashes only the regions of the Linux files', () {
      String begin(String name, String comment) =>
          '$comment ----- BEGIN $name (autogenerated by flutter_flavorizr) -----\n';
      String end(String name, String comment) =>
          '$comment ----- END $name (autogenerated by flutter_flavorizr) -----\n';
      // The payload is the only thing the tests below change: the markers stay
      // as they are, so the region stays balanced.
      String region(String name, String comment, String payload) =>
          '${begin(name, comment)}$payload\n${end(name, comment)}';

      for (final (path, name, comment) in [
        ('linux/CMakeLists.txt', 'APPLICATION_ID', '#'),
        ('linux/runner/CMakeLists.txt', 'FLUTTER_APP_FLAVOR', '#'),
        ('linux/runner/my_application.cc', 'window_title', '//'),
      ]) {
        final artifact = Artifact.patched(path);
        final owned = region(name, comment, 'PAYLOAD_ONE');
        final plain = registry.hash(artifact, _bytes('first\n$owned'));

        expect(
          registry.hash(artifact, _bytes('second\n// mine\n$owned')),
          plain,
          reason: '$path: what is outside the region is not hashed',
        );
        expect(
          registry.hash(
            artifact,
            _bytes('first\n${region(name, comment, 'PAYLOAD_TWO')}'),
          ),
          isNot(plain),
          reason: '$path: what is inside the region is hashed',
        );
      }
    });

    test('hashes a patched file nobody knows whole', () {
      expect(
        registry.hash(const Artifact.patched('other'), _bytes('abc')),
        digestOf(_bytes('abc')),
      );
    });

    test('the paths of a run are the ones its processors work on', () {
      expect(registry.pathsOf([registry.engineProcessors['android:icons']!]), {
        'android/app/src',
      });
    });
  });
}
