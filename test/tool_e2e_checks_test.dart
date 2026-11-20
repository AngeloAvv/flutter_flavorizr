import 'dart:typed_data';

import 'package:test/test.dart';

import '../tool/e2e/checks.dart';

/// A PNG header (signature and `IHDR`) for an image of [width] x [height].
Uint8List _png(int width, int height) {
  final bytes = Uint8List(33)
    ..setAll(0, [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
    ..setAll(8, [0, 0, 0, 13, 0x49, 0x48, 0x44, 0x52]);

  for (final (offset, value) in [(16, width), (20, height)]) {
    bytes.setAll(offset, [
      value >> 24 & 0xFF,
      value >> 16 & 0xFF,
      value >> 8 & 0xFF,
      value & 0xFF,
    ]);
  }

  return bytes;
}

void main() {
  group('planChanges', () {
    test('reads the changes of the document', () {
      expect(planChanges('{"changes":[]}\n'), isEmpty);
      expect(
        planChanges('{"changes":[{"path":"a"},{"path":"b"}]}'),
        hasLength(2),
      );
    });

    test('skips the lines `dart run` prints, and takes the last document', () {
      expect(
        planChanges('Building package executable...\nBuilt.\n{"changes":[1]}'),
        [1],
      );
      expect(planChanges('{"changes":[1]}\n{"changes":[]}\n'), isEmpty);
    });

    test('is null when there is no document, or no changes in it', () {
      expect(planChanges(''), isNull);
      expect(planChanges('nothing to do\n'), isNull);
      expect(planChanges('{"summary":{}}'), isNull);
      expect(planChanges('{"changes":"none"}'), isNull);
    });
  });

  group('dirtyPaths', () {
    test('is empty for a clean tree', () {
      expect(dirtyPaths(''), isEmpty);
      expect(dirtyPaths('\n\n'), isEmpty);
    });

    test('lists every path git reports', () {
      expect(
        dirtyPaths(
          ' M windows/runner/Runner.rc\n'
          '?? windows/runner/main.cpp\r\n'
          'D  windows/runner/resources/banana.ico\n',
        ),
        [
          ' M windows/runner/Runner.rc',
          '?? windows/runner/main.cpp',
          'D  windows/runner/resources/banana.ico',
        ],
      );
    });
  });

  group('png', () {
    test('reads the size of the header', () {
      expect(pngSize(_png(192, 96)), (width: 192, height: 96));
      expect(pngSize(_png(4096, 1)), (width: 4096, height: 1));
    });

    test('is none for what is not a PNG', () {
      expect(isPng(_png(1, 1)), isTrue);
      expect(isPng(Uint8List(33)), isFalse);
      expect(isPng([0x89, 0x50]), isFalse);
      expect(pngSize(Uint8List(33)), isNull);
      expect(pngSize([]), isNull);
    });
  });

  group('icoImageCount', () {
    test('counts the images of an ICO', () {
      expect(icoImageCount([0, 0, 1, 0, 4, 0, 16, 16]), 4);
      expect(icoImageCount([0, 0, 1, 0, 0, 1]), 256);
    });

    test('is null for what is not an ICO, or has no image', () {
      expect(icoImageCount([0, 0, 1, 0, 0, 0]), isNull);
      expect(icoImageCount([0, 0, 2, 0, 1, 0]), isNull);
      expect(icoImageCount([1, 0, 1, 0, 1, 0]), isNull);
      expect(icoImageCount([0, 0, 1]), isNull);
      expect(icoImageCount(_png(16, 16)), isNull);
    });
  });

  group('manifest placeholders', () {
    const manifest = '''
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application
        android:label="e2e_app">
        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
    </application>
</manifest>
''';

    test('manifestWithPlaceholder adds the meta-data inside application', () {
      final edited = manifestWithPlaceholder(
        manifest,
        name: 'e2e.scheme',
        placeholder: 'scheme',
      );

      expect(edited, contains(r'android:value="${scheme}"'));
      expect(
        edited.indexOf('e2e.scheme'),
        lessThan(edited.indexOf('</application>')),
      );
      expect(
        edited.indexOf('e2e.scheme'),
        greaterThan(edited.indexOf('flutterEmbedding')),
      );
    });

    test('manifestWithPlaceholder needs an application', () {
      expect(
        () => manifestWithPlaceholder(
          '<manifest />',
          name: 'a',
          placeholder: 'b',
        ),
        throwsFormatException,
      );
    });

    test('metaDataValues reads the placeholder as written', () {
      final edited = manifestWithPlaceholder(
        manifest,
        name: 'e2e.scheme',
        placeholder: 'scheme',
      );

      expect(metaDataValues(edited, 'e2e.scheme'), [r'${scheme}']);
    });

    test('metaDataValues reads the value that was merged', () {
      expect(
        metaDataValues(
          '<application><meta-data android:value="scheme-apple" '
              'android:name="e2e.scheme"/><meta-data\n'
              '  android:name="other"\n  android:value="x"/></application>',
          'e2e.scheme',
        ),
        ['scheme-apple'],
      );
    });

    test('metaDataValues is empty for another name', () {
      expect(metaDataValues(manifest, 'e2e.scheme'), isEmpty);
      expect(metaDataValues(manifest, 'flutterEmbedding'), ['2']);
      expect(metaDataValues(manifest, 'flutter'), isEmpty);
    });
  });

  group('groovy project', () {
    const settings = '''
pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            properties.getProperty("flutter.sdk")
        }

    includeBuild("\$flutterSdkPath/packages/flutter_tools/gradle")
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.1.0" apply false
    id("org.jetbrains.kotlin.android") version "2.4.0" apply false
}

include(":app")
''';

    test('groovySettings keeps the plugins and their versions', () {
      final groovy = groovySettings(settings);

      expect(
        groovy,
        contains('id "dev.flutter.flutter-plugin-loader" version'),
      );
      expect(groovy, contains('id "com.android.application" version "9.1.0"'));
      expect(
        groovy,
        contains('id "org.jetbrains.kotlin.android" version "2.4.0"'),
      );
      expect(groovy, contains('include ":app"'));
    });

    test('groovySettings has no Kotlin left in it', () {
      final groovy = groovySettings(settings);

      expect(groovy, startsWith('pluginManagement {'));
      expect(groovy, contains('def flutterSdkPath'));
      expect(groovy, contains(r'includeBuild("$flutterSdkPath/'));
      expect(groovy, isNot(contains('val ')));
      expect(groovy, isNot(contains('id("')));
      expect(groovy, isNot(contains('include(')));
    });

    test('groovySettings needs the plugins block', () {
      expect(
        () => groovySettings('pluginManagement {}\ninclude(":app")'),
        throwsFormatException,
      );
    });

    test('groovyAppBuild enables resValues at the top of android', () {
      const build = '''
plugins {
    id("com.android.application")
}

android {
    namespace = "com.example.e2e_app"
    defaultConfig {
        applicationId = "com.example.e2e_app"
    }
}
''';

      expect(groovyAppBuild(build), '''
plugins {
    id("com.android.application")
}

android {
    buildFeatures {
        resValues = true
    }

    namespace = "com.example.e2e_app"
    defaultConfig {
        applicationId = "com.example.e2e_app"
    }
}
''');
    });

    test('groovyAppBuild needs the android block', () {
      expect(() => groovyAppBuild('plugins {}\n'), throwsFormatException);
    });

    test('groovyRootBuild is Groovy', () {
      expect(groovyRootBuild, contains('tasks.register("clean", Delete)'));
      expect(groovyRootBuild, isNot(contains('val ')));
      expect(groovyRootBuild, isNot(contains('<Delete>')));
    });
  });
}
