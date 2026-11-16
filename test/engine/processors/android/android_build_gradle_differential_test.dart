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
import 'package:flutter_flavorizr/src/engine/processors/android/android_build_gradle_patch_processor.dart';
import 'package:flutter_flavorizr/src/exception/file_not_found_exception.dart';
import 'package:flutter_flavorizr/src/processors/android/build_gradle/android_build_kotlin_processor.dart';
import 'package:flutter_flavorizr/src/processors/android/build_gradle/android_build_legacy_processor.dart';
import 'package:flutter_flavorizr/src/processors/commons/apply_processor_by_existing_file_processor.dart';
import 'package:flutter_flavorizr/src/utils/constants.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../../test_utils.dart';

/// Runs the 2.x `android:buildGradle` processor and the ported one on
/// identical projects and compares what they produce.
///
/// The 2.x processors are driven with absolute paths, which they accept, so
/// the working directory is never involved. The CLI does not exist yet, so this
/// is the equivalence check the golden parity harness (`tool/parity`) will do
/// end to end later. Every difference that is intended is asserted explicitly
/// below, and listed in the pull request: they are the entries of the parity
/// whitelist to come.
///
/// Intentional differences:
///
/// 1. A build file with CRLF line endings: 2.x appends the region with LF line
///    endings, the port with the ones of the file.
/// 2. A region that is up to date but was moved by the user: 2.x moves it back
///    to the end of the file, the port leaves it where it is.
/// 3. An unmarked line that applies the flavors file (hand written): 2.x adds a
///    region and leaves the line, which applies the file twice, the port adopts
///    the line into the region, in place.
/// 4. An end marker before the begin marker: 2.x does not see a region and adds
///    another one, the port refuses to touch the file.
///
/// 5. Whitespace around a marker, CRLF included (2.x only sees a marker at the
///    start of a line, right before a `\n`): a region that 2.x does not find
///    and duplicates, the port finds. So an up to date region with CRLF line
///    endings or trailing white space is left alone, where 2.x adds a second
///    region.
/// 6. A byte order mark: 2.x drops it, the port keeps it.
/// 7. An up to date region at the end of a file that ends with a line break:
///    2.x removes the region and its line break and writes the region again,
///    without it, so the file loses its last line break (the Kotlin fixtures
///    of 2.x have none); the port does not touch it.
///
/// Everything else is byte for byte the same, including the failures.
void main() {
  const fixtures = 'test_resources/android';

  // The build files both processors are fed, by DSL.
  final inputs = {
    'Groovy': (
      name: 'build.gradle',
      ok: [
        '$fixtures/engine_android/build_flutter_create.gradle',
        '$fixtures/build_legacy_processor_test/build_original.gradle',
        // An old region that declares the flavors: it is moved and replaced.
        '$fixtures/build_legacy_processor_test/build_idempotent_1.gradle',
      ],
      failing: [
        '$fixtures/build_legacy_processor_test/build_malformed_1.gradle',
        '$fixtures/build_legacy_processor_test/build_malformed_2.gradle',
        '$fixtures/build_legacy_processor_test/build_malformed_3.gradle',
      ],
    ),
    'Kotlin': (
      name: 'build.gradle.kts',
      ok: [
        '$fixtures/engine_android/build_flutter_create.gradle.kts',
        '$fixtures/build_kotlin_processor_test/build_original.gradle.kts',
        '$fixtures/build_kotlin_processor_test/build_idempotent_1.gradle.kts',
        '$fixtures/build_kotlin_processor_test/build_idempotent_2.gradle.kts',
        '$fixtures/build_kotlin_processor_test/build_expected.gradle.kts',
      ],
      failing: [
        '$fixtures/build_kotlin_processor_test/build_malformed_1.gradle.kts',
        '$fixtures/build_kotlin_processor_test/build_malformed_2.gradle.kts',
        '$fixtures/build_kotlin_processor_test/build_malformed_3.gradle.kts',
      ],
    ),
  };

  late Directory legacyProject;
  late Directory portedProject;

  String build(Directory project, String name) =>
      p.join(project.path, 'android/app', name);

  /// Runs 2.x on [content] and returns the new content of the build file, or
  /// the exception it failed with.
  Future<Object> legacy(String name, String content) async {
    final config = TestUtils.parseFlavorizr('test_resources/pubspec');
    final logger = TestUtils.quietLogger();
    final file = File(build(legacyProject, name))
      ..createSync(recursive: true)
      ..writeAsStringSync(content);

    try {
      await ApplyProcessorByExistingFileProcessor(
        [
          build(legacyProject, 'build.gradle'),
          build(legacyProject, 'build.gradle.kts'),
        ],
        [
          AndroidBuildLegacyProcessor(
            K.androidFlavorizrLegacyName,
            config: config,
            logger: logger,
          ),
          AndroidBuildKotlinProcessor(
            K.androidFlavorizrKotlinName,
            config: config,
            logger: logger,
          ),
        ],
        config: config,
        logger: logger,
      ).execute();
    } on Exception catch (e) {
      return e;
    }

    return file.readAsStringSync();
  }

  /// The same with the port.
  Future<Object> ported(String name, String content) async {
    final file = File(build(portedProject, name))
      ..createSync(recursive: true)
      ..writeAsStringSync(content);

    try {
      await const AndroidBuildGradlePatchProcessor().apply(
        FlavorizrContext(
          config: TestUtils.parseFlavorizr('test_resources/pubspec'),
          root: portedProject,
          projectRoot: portedProject,
          logger: TestUtils.quietLogger(),
        ),
      );
    } on Exception catch (e) {
      return e;
    }

    return file.readAsStringSync();
  }

  setUp(() {
    final temp = Directory.systemTemp.createTempSync('flavorizr_build_diff_');
    addTearDown(() => temp.deleteSync(recursive: true));

    legacyProject = Directory(p.join(temp.path, 'legacy'))..createSync();
    portedProject = Directory(p.join(temp.path, 'ported'))..createSync();
  });

  for (final MapEntry(key: dsl, value: (:name, :ok, :failing))
      in inputs.entries) {
    for (final path in ok) {
      test('the build file ${p.basename(path)} ends up as in 2.x ($dsl), and '
          'a second run changes nothing', () async {
        final content = File(path).readAsStringSync();

        final expected = await legacy(name, content);
        final actual = await ported(name, content);

        expect(expected, isA<String>());
        expect(actual, expected);
        // Idempotent in both.
        expect(await ported(name, actual as String), actual);
        expect(await legacy(name, expected as String), expected);
      });
    }

    for (final path in failing) {
      test(
        'the build file ${p.basename(path)} fails as in 2.x ($dsl)',
        () async {
          final content = File(path).readAsStringSync();

          final expected = await legacy(name, content);
          final actual = await ported(name, content);

          expect(expected, isA<Exception>());
          expect(actual.runtimeType, expected.runtimeType);
        },
      );
    }

    test(
      'a build file without the android block fails as in 2.x ($dsl)',
      () async {
        for (final content in ['', 'plugins {}\n']) {
          final expected = await legacy(name, content);
          final actual = await ported(name, content);

          expect(expected, isA<Exception>());
          expect(actual.runtimeType, expected.runtimeType);
        }
      },
    );

    test('a missing build file fails as in 2.x ($dsl)', () async {
      final config = TestUtils.parseFlavorizr('test_resources/pubspec');
      final logger = TestUtils.quietLogger();

      expect(
        () => ApplyProcessorByExistingFileProcessor(
          [
            build(legacyProject, 'build.gradle'),
            build(legacyProject, 'build.gradle.kts'),
          ],
          [
            AndroidBuildLegacyProcessor('x', config: config, logger: logger),
            AndroidBuildKotlinProcessor('x', config: config, logger: logger),
          ],
          config: config,
          logger: logger,
        ),
        throwsA(isA<FileNotFoundException>()),
      );
      await expectLater(
        const AndroidBuildGradlePatchProcessor().apply(
          FlavorizrContext(
            config: config,
            root: portedProject,
            projectRoot: portedProject,
            logger: logger,
          ),
        ),
        throwsA(isA<FileNotFoundException>()),
      );
    });
  }

  group('Intentional differences', () {
    test('#5 a region with CRLF or trailing white space is found', () async {
      const base = 'plugins {}\n\nandroid {\n}\n';
      const begin =
          '// ----- BEGIN flavorDimensions (autogenerated by flutter_flavorizr) -----';
      const end =
          '// ----- END flavorDimensions (autogenerated by flutter_flavorizr) -----';
      const apply = 'apply from: "flavorizr.gradle"';

      for (final content in [
        '${base.replaceAll('\n', '\r\n')}$begin\r\n$apply\r\n$end\r\n',
        '$base$begin \n$apply\n$end\t\n',
      ]) {
        final expected = await legacy('build.gradle', content);
        final actual = await ported('build.gradle', content);

        expect(expected, isNot(content));
        expect(
          RegExp('BEGIN').allMatches(expected as String),
          hasLength(2),
          reason: '2.x duplicates the region',
        );
        expect(actual, content);
      }
    });

    test('#6 the byte order mark is kept', () async {
      const content = '\u{feff}plugins {}\n\nandroid {\n}\n';

      await legacy('build.gradle', content);
      await ported('build.gradle', content);

      expect(
        File(build(legacyProject, 'build.gradle')).readAsBytesSync().take(3),
        isNot([0xef, 0xbb, 0xbf]),
      );
      expect(
        File(build(portedProject, 'build.gradle')).readAsBytesSync().take(3),
        [0xef, 0xbb, 0xbf],
      );
    });

    test(
      '#7 an up to date region is not touched, line break included',
      () async {
        final content = File(
          '$fixtures/build_legacy_processor_test/build_expected.gradle',
        ).readAsStringSync();

        final expected = await legacy('build.gradle', content);
        final actual = await ported('build.gradle', content);

        expect(content, endsWith('-----\n'));
        expect(expected, content.substring(0, content.length - 1));
        expect(actual, content);
      },
    );

    const groovy = 'build.gradle';
    const begin =
        '// ----- BEGIN flavorDimensions (autogenerated by flutter_flavorizr) -----';
    const end =
        '// ----- END flavorDimensions (autogenerated by flutter_flavorizr) -----';
    const apply = 'apply from: "flavorizr.gradle"';
    const region = '$begin\n$apply\n$end';
    const base = 'plugins {}\n\nandroid {\n}\n';

    test('#1 line endings: the region follows the file', () async {
      final crlf = base.replaceAll('\n', '\r\n');

      final expected = await legacy(groovy, crlf);
      final actual = await ported(groovy, crlf);

      expect(expected, '$crlf$region');
      expect(actual, '$crlf${region.replaceAll('\n', '\r\n')}');
    });

    test(
      '#2 a region that is up to date stays where the user put it',
      () async {
        const moved = 'plugins {}\n\n$region\n\nandroid {\n}\n';
        final indented = 'android {\n  ${region.replaceAll('\n', '\n  ')}\n}\n';

        final expected = await legacy(groovy, moved);
        final actual = await ported(groovy, moved);

        expect(expected, 'plugins {}\n\n\nandroid {\n}\n$region');
        expect(actual, moved);

        // An indentation is no reason to move it either.
        expect(await legacy(groovy, indented), 'android {\n}\n$region');
        expect(await ported(groovy, indented), indented);
      },
    );

    test('#3 an unmarked line is adopted instead of applied twice', () async {
      const unmarked = '$base$apply\n';

      final expected = await legacy(groovy, unmarked);
      final actual = await ported(groovy, unmarked);

      expect(expected, '$unmarked$region');
      expect(actual, '$base$region\n');
    });

    test(
      '#4 a region whose markers are the wrong way round is refused',
      () async {
        const reversed = '$base$end\n$begin\n';

        final expected = await legacy(groovy, reversed);
        final actual = await ported(groovy, reversed);

        expect(expected, '$reversed$region');
        expect(actual, isA<Exception>());
        expect(File(build(portedProject, groovy)).readAsStringSync(), reversed);
      },
    );
  });
}
