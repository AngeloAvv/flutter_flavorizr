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

import 'package:flutter_flavorizr/src/engine/artifact.dart';
import 'package:flutter_flavorizr/src/engine/flavorizr_context.dart';
import 'package:flutter_flavorizr/src/engine/processors/android/flavorizr_gradle_processor.dart';
import 'package:flutter_flavorizr/src/exception/file_not_found_exception.dart';
import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;

import '../../../test_utils.dart';

const _twoFlavors = '''
flavors:
  apple:
    app:
      name: "Apple App"
    android:
      applicationId: "com.example.apple"
  banana:
    app:
      name: "Banana App"
    android:
      applicationId: "com.example.banana"
''';

const _oneFlavor = '''
flavors:
  apple:
    app:
      name: "Apple App"
    android:
      applicationId: "com.example.apple"
''';

const _groovyApple = '''
android {
    flavorDimensions += "flavor-type"

    productFlavors {
        apple {
            dimension "flavor-type"
            applicationId "com.example.apple"
            resValue "string", "app_name", "Apple App"
        }
    }
}''';

const _kotlinApple = '''
import com.android.build.api.dsl.ApplicationExtension

val android = project.extensions.getByType(ApplicationExtension::class.java)

android.apply {
    flavorDimensions += "flavor-type"

    productFlavors {
        create("apple") {
            dimension = "flavor-type"
            applicationId = "com.example.apple"
            resValue(type = "string", name = "app_name", value = "Apple App")
        }
    }

    buildFeatures.resValues = true
}''';

void main() {
  late Directory root;
  late Directory projectRoot;

  FlavorizrContext contextFor(String yaml) => FlavorizrContext(
    config: FlavorizrConfig.parse(yaml),
    root: root,
    projectRoot: projectRoot,
    logger: TestUtils.quietLogger(),
  );

  File inRoot(String path) => File(p.join(root.path, path));

  void createGradle(String name) =>
      File(p.join(projectRoot.path, 'android/app/$name'))
        ..createSync(recursive: true)
        ..writeAsStringSync('// $name');

  setUp(() {
    final temp = Directory.systemTemp.createTempSync('flavorizr_gradle_');
    addTearDown(() => temp.deleteSync(recursive: true));

    root = Directory(p.join(temp.path, 'shadow'))..createSync();
    projectRoot = Directory(p.join(temp.path, 'project'))..createSync();
  });

  group('FlavorizrGradleProcessor', () {
    test('is the `android:flavorizrGradle` processor, with no edges', () {
      const processor = FlavorizrGradleProcessor();

      expect(processor.id, 'android:flavorizrGradle');
      expect(processor.dependsOn, isEmpty);
      expect(processor.after, isEmpty);
      expect(processor.requires, isEmpty);
    });

    test('writes `flavorizr.gradle` next to a Groovy build file', () async {
      createGradle('build.gradle');
      final ctx = contextFor(_oneFlavor);

      await const FlavorizrGradleProcessor().apply(ctx);

      expect(
        inRoot('android/app/flavorizr.gradle').readAsStringSync(),
        _groovyApple,
      );
      expect(inRoot('android/app/flavorizr.gradle.kts').existsSync(), isFalse);
      expect(ctx.tracked, [
        const Artifact.managed('android/app/flavorizr.gradle'),
      ]);
    });

    test('writes `flavorizr.gradle.kts` next to a Kotlin build file', () async {
      createGradle('build.gradle.kts');
      final ctx = contextFor(_oneFlavor);

      await const FlavorizrGradleProcessor().apply(ctx);

      expect(
        inRoot('android/app/flavorizr.gradle.kts').readAsStringSync(),
        _kotlinApple,
      );
      expect(inRoot('android/app/flavorizr.gradle').existsSync(), isFalse);
      expect(ctx.tracked, [
        const Artifact.managed('android/app/flavorizr.gradle.kts'),
      ]);
    });

    test('prefers Groovy when both build files exist, like 2.x', () async {
      createGradle('build.gradle');
      createGradle('build.gradle.kts');
      final ctx = contextFor(_oneFlavor);

      await const FlavorizrGradleProcessor().apply(ctx);

      expect(inRoot('android/app/flavorizr.gradle').existsSync(), isTrue);
      expect(inRoot('android/app/flavorizr.gradle.kts').existsSync(), isFalse);
    });

    test('fails when the project has no build file', () {
      expect(
        const FlavorizrGradleProcessor().apply(contextFor(_oneFlavor)),
        throwsA(isA<FileNotFoundException>()),
      );
    });

    test('regenerates the file from scratch, so a removed flavor is dropped, '
        'and a second run changes nothing', () async {
      createGradle('build.gradle');

      await const FlavorizrGradleProcessor().apply(contextFor(_twoFlavors));
      final withBanana = inRoot(
        'android/app/flavorizr.gradle',
      ).readAsStringSync();

      expect(withBanana, contains('banana {'));

      await const FlavorizrGradleProcessor().apply(contextFor(_oneFlavor));
      final withoutBanana = inRoot(
        'android/app/flavorizr.gradle',
      ).readAsStringSync();

      expect(withoutBanana, _groovyApple);

      await const FlavorizrGradleProcessor().apply(contextFor(_oneFlavor));

      expect(
        inRoot('android/app/flavorizr.gradle').readAsStringSync(),
        withoutBanana,
      );
    });

    test('overwrites a stale `flavorizr.gradle.kts` of the project', () async {
      createGradle('build.gradle.kts');
      inRoot('android/app/flavorizr.gradle.kts')
        ..createSync(recursive: true)
        ..writeAsStringSync('stale');

      await const FlavorizrGradleProcessor().apply(contextFor(_oneFlavor));

      expect(
        inRoot('android/app/flavorizr.gradle.kts').readAsStringSync(),
        _kotlinApple,
      );
    });
  });
}
