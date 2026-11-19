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

import 'package:flutter_flavorizr/src/engine/flavorizr_context.dart';
import 'package:flutter_flavorizr/src/engine/processors/android/android_manifest_patch_processor.dart';
import 'package:flutter_flavorizr/src/engine/processors/android/flavorizr_gradle_processor.dart';
import 'package:flutter_flavorizr/src/processors/android/android_manifest_processor.dart';
import 'package:flutter_flavorizr/src/processors/android/build_gradle/android_flavorizr_gradle_processor.dart';
import 'package:flutter_flavorizr/src/processors/android/build_gradle/android_flavorizr_kotlin_processor.dart';
import 'package:flutter_flavorizr/src/processors/android/build_gradle/android_flavorizr_legacy_processor.dart';
import 'package:flutter_flavorizr/src/processors/commons/existing_file_string_processor.dart';
import 'package:flutter_flavorizr/src/utils/constants.dart';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import '../../../test_utils.dart';

/// Runs the 2.x processors and the ported ones on identical projects and
/// compares what they produce.
///
/// The 2.x processors are driven with absolute paths, which they accept, so
/// the working directory is never involved. The CLI does not exist yet, so
/// this is the equivalence check the golden parity harness (`tool/parity`)
/// will do end to end later. Every difference that is intended is asserted
/// explicitly below, and listed in the pull request: they are the entries of
/// the parity whitelist to come.
///
/// Intentional differences:
///
/// 1. `AndroidManifest.xml` is no longer serialized again. 2.x pretty prints
///    the whole document (attributes of an element on one line, comments and
///    indentation normalized, XML declaration kept as it is); the port changes
///    the value of `android:label` and nothing else. The two documents are
///    equal as XML, which is asserted too.
///
/// There are none for `flavorizr.gradle(.kts)`: the content is byte for byte
/// the same.
void main() {
  // The fixture, the label of its application as the user wrote it and what
  // it becomes.
  const manifests = {
    'flutter create': (
      'AndroidManifest_flutter_create.xml',
      'android:label="parity_app"',
      'android:label="@string/app_name"',
    ),
    'customized': (
      'AndroidManifest_customized.xml',
      "android:label='Customized'",
      "android:label='@string/app_name'",
    ),
    '2.x test resource': (
      '../android_manifest_processor_test/AndroidManifest.xml',
      'android:label="example"',
      'android:label="@string/app_name"',
    ),
  };
  final configs = {
    'default': 'test_resources/pubspec',
    'custom config':
        'test/processors/android/build_flavorizr_processor_test/'
        'pubspec_with_custom_config',
  };
  final gradleFiles = {
    'Groovy': ['build.gradle', 'flavorizr.gradle'],
    'Kotlin': ['build.gradle.kts', 'flavorizr.gradle.kts'],
  };

  late Directory legacyProject;
  late Directory portedProject;

  String read(Directory project, String path) =>
      File(p.join(project.path, path)).readAsStringSync();

  Map<String, String> snapshot(Directory project) => {
    for (final file in project.listSync(recursive: true).whereType<File>())
      p.relative(file.path, from: project.path): file.readAsStringSync(),
  };

  void createProject(
    Directory project, {
    required String build,
    required String manifest,
  }) {
    File(p.join(project.path, 'android/app/$build'))
      ..createSync(recursive: true)
      ..writeAsStringSync('// the build file of the user\n');
    File(p.join(project.path, K.androidManifestPath))
      ..createSync(recursive: true)
      ..writeAsStringSync(manifest);
  }

  setUp(() {
    final temp = Directory.systemTemp.createTempSync('flavorizr_diff_');
    addTearDown(() => temp.deleteSync(recursive: true));

    legacyProject = Directory(p.join(temp.path, 'legacy'))..createSync();
    portedProject = Directory(p.join(temp.path, 'ported'))..createSync();
  });

  for (final MapEntry(key: dsl, value: [build, flavorizr])
      in gradleFiles.entries) {
    for (final MapEntry(key: configName, value: pubspec) in configs.entries) {
      test(
        'flavorizr.gradle is the same as in 2.x ($dsl, $configName)',
        () async {
          final config = TestUtils.parseFlavorizr(pubspec);
          final logger = TestUtils.quietLogger();
          createProject(legacyProject, build: build, manifest: '<a/>');
          createProject(portedProject, build: build, manifest: '<a/>');

          String path(Directory project, String file) =>
              p.join(project.path, 'android/app', file);

          await AndroidFlavorizrGradleProcessor(
            [
              path(legacyProject, 'build.gradle'),
              path(legacyProject, 'build.gradle.kts'),
            ],
            [
              path(legacyProject, 'flavorizr.gradle'),
              path(legacyProject, 'flavorizr.gradle.kts'),
            ],
            [
              AndroidFlavorizrLegacyProcessor(config: config, logger: logger),
              AndroidFlavorizrKotlinProcessor(config: config, logger: logger),
            ],
            config: config,
            logger: logger,
          ).execute();
          await const FlavorizrGradleProcessor().apply(
            FlavorizrContext(
              config: config,
              root: portedProject,
              projectRoot: portedProject,
              logger: logger,
            ),
          );

          expect(snapshot(portedProject), snapshot(legacyProject));
          expect(read(portedProject, 'android/app/$flavorizr'), isNot(isEmpty));
        },
      );
    }
  }

  for (final MapEntry(key: name, value: (resource, before, after))
      in manifests.entries) {
    test('the manifest "$name" is the same XML as in 2.x, and only the label '
        'differs from the original', () async {
      final original = File(
        p.join('test_resources/android/engine_android', resource),
      ).readAsStringSync();
      final config = TestUtils.parseFlavorizr('test_resources/pubspec');
      final logger = TestUtils.quietLogger();
      createProject(legacyProject, build: 'build.gradle', manifest: original);
      createProject(portedProject, build: 'build.gradle', manifest: original);

      await ExistingFileStringProcessor(
        p.join(legacyProject.path, K.androidManifestPath),
        AndroidManifestProcessor(config: config, logger: logger),
        config: config,
        logger: logger,
      ).execute();
      await const AndroidManifestPatchProcessor().apply(
        FlavorizrContext(
          config: config,
          root: portedProject,
          projectRoot: portedProject,
          logger: logger,
        ),
      );

      final legacy = read(legacyProject, K.androidManifestPath);
      final ported = read(portedProject, K.androidManifestPath);

      // The same document...
      expect(
        XmlDocument.parse(ported).toXmlString(pretty: true),
        XmlDocument.parse(legacy).toXmlString(pretty: true),
      );
      expect(
        XmlDocument.parse(
          ported,
        ).findAllElements('application').first.getAttribute('android:label'),
        '@string/app_name',
      );
      // ... that keeps the formatting of the user: intended difference #1.
      expect(ported, isNot(legacy));
      expect(ported, original.replaceFirst(before, after));
      // Every other file is as it was.
      expect(
        snapshot(portedProject)..remove(K.androidManifestPath),
        snapshot(legacyProject)..remove(K.androidManifestPath),
      );
    });
  }
}
