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
import 'dart:typed_data';

import 'package:flutter_flavorizr/src/engine/flavorizr_context.dart';
import 'package:flutter_flavorizr/src/engine/processors/android/android_icons_processor.dart';
import 'package:flutter_flavorizr/src/exception/file_not_found_exception.dart';
import 'package:flutter_flavorizr/src/exception/malformed_resource_exception.dart';
import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:flutter_flavorizr/src/processors/android/icons/android_icons_processor.dart'
    as legacy;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../../../test_utils.dart';
import 'android_icon_source_test.dart' show gradientPng;
import 'posix_paths.dart';

/// Runs the 2.x `android:icons` processor and the ported one on identical
/// projects and compares every generated file byte for byte.
///
/// The 2.x processor works on paths relative to the working directory, so
/// this test moves the working directory to the legacy project while it runs
/// (and restores it). The ported processor is given the project and a separate
/// workspace, as the engine does. The CLI does not exist yet, so this is the
/// equivalence check the golden parity harness (`tool/parity`) will do end to
/// end later.
///
/// Intentional differences (1, 2 and 5 are asserted below, 3 and 4 in
/// `android_icons_processor_test.dart` and `android_icon_source_test.dart`):
///
/// 1. A missing source icon is a `FileNotFoundException` (2.x: the
///    `PathNotFoundException` of the file system) and a source that is not an
///    image a `MalformedResourceException` (2.x: a `FileNotFoundException`,
///    which blames a file that does exist).
/// 2. Nothing is written when any source fails (2.x leaves the icons of the
///    flavors it had already processed).
/// 3. The source must stay inside the project, links included (2.x reads any
///    path, `..` and absolute paths too), and is refused when it is larger
///    than 32 MiB or has a side longer than 4096 pixels.
/// 4. A flavor name that is not a single directory name is refused.
/// 5. Of an animated source only the first frame is used.
///
/// There is no difference in the files generated for a valid source: same
/// paths, same bytes.
void main() {
  late Directory legacyProject;
  late Directory portedProject;
  late Directory workspace;
  late Directory originalCwd;

  const flavors = '''
flavors:
  apple:
    app:
      name: "Apple"
      icon: "assets/apple.png"
    android:
      applicationId: "com.example.apple"
  banana:
    app:
      name: "Banana"
      icon: "assets/app.png"
    android:
      applicationId: "com.example.banana"
      icon: "assets/banana.jpg"
  cherry:
    app:
      name: "Cherry"
    android:
      applicationId: "com.example.cherry"
      adaptiveIcon:
        foreground: "assets/fg.png"
        background: "assets/bg.png"
  durian:
    app:
      name: "Durian"
      icon: "assets/wide.png"
    android:
      applicationId: "com.example.durian"
      adaptiveIcon:
        foreground: "assets/fg.png"
        background: "assets/bg.png"
        monochrome: "assets/mono.png"
  elder:
    app:
      name: "Elder"
    android:
      applicationId: "com.example.elder"
    ios:
      bundleId: "com.example.elder"
''';

  final fixtures = <String, Uint8List>{
    'assets/apple.png': gradientPng(512, 512),
    'assets/app.png': gradientPng(100, 100),
    'assets/banana.jpg': img.encodeJpg(
      img.decodePng(gradientPng(300, 300))!,
      quality: 90,
    ),
    'assets/fg.png': gradientPng(432, 432),
    'assets/bg.png': gradientPng(64, 64),
    'assets/mono.png': gradientPng(200, 200),
    'assets/wide.png': gradientPng(400, 120),
  };

  void createProject(Directory project, [Map<String, Uint8List>? files]) {
    for (final MapEntry(key: path, value: bytes)
        in (files ?? fixtures).entries) {
      File(p.join(project.path, path))
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes);
    }
  }

  Map<String, List<int>> snapshot(Directory directory) => {
    for (final file in directory.listSync(recursive: true).whereType<File>())
      relativePosix(file.path, from: directory.path): file.readAsBytesSync(),
  };

  /// What a processor produced, without the fixtures.
  Map<String, List<int>> generated(Directory directory) => {
    for (final MapEntry(:key, :value) in snapshot(directory).entries)
      if (key.startsWith('android/')) key: value,
  };

  Future<void> runLegacy(String yaml) async {
    final config = Flavorizr.parse(yaml);

    Directory.current = legacyProject;
    try {
      await legacy.AndroidIconsProcessor(
        config: config,
        logger: TestUtils.quietLogger(),
      ).execute();
    } finally {
      Directory.current = originalCwd;
    }
  }

  Future<FlavorizrContext> runPorted(String yaml) async {
    final ctx = FlavorizrContext(
      config: Flavorizr.parse(yaml),
      root: workspace,
      projectRoot: portedProject,
      logger: TestUtils.quietLogger(),
    );

    await const AndroidIconsProcessor().apply(ctx);

    return ctx;
  }

  setUp(() {
    originalCwd = Directory.current;
    final temp = Directory.systemTemp.createTempSync('flavorizr_icons_diff_');
    addTearDown(() {
      Directory.current = originalCwd;
      temp.deleteSync(recursive: true);
    });

    legacyProject = Directory(p.join(temp.path, 'legacy'))..createSync();
    portedProject = Directory(p.join(temp.path, 'ported'))..createSync();
    workspace = Directory(p.join(temp.path, 'workspace'))..createSync();
    createProject(legacyProject);
    createProject(portedProject);
  });

  test('every icon is the same file as in 2.x, byte for byte', () async {
    await runLegacy(flavors);
    final ctx = await runPorted(flavors);

    final expected = generated(legacyProject);
    final actual = snapshot(workspace);

    // 5 launcher icons for apple, banana, durian; 11 adaptive for cherry and
    // 16 for durian.
    expect(expected.keys, hasLength(5 * 3 + 11 + 16));
    expect(actual.keys.toSet(), expected.keys.toSet());
    for (final path in expected.keys) {
      expect(actual[path], expected[path], reason: path);
    }
    expect(
      ctx.tracked.map((artifact) => artifact.path).toSet(),
      actual.keys.toSet(),
    );
  });

  test('an ICO source is the same file as in 2.x, byte for byte', () async {
    final image = img.Image(width: 32, height: 32, numChannels: 4)
      ..clear(img.ColorRgba8(10, 200, 30, 255));
    final files = {'assets/apple.ico': img.encodeIco(image)};
    createProject(legacyProject, files);
    createProject(portedProject, files);
    const yaml = '''
flavors:
  apple:
    app:
      name: "Apple"
      icon: "assets/apple.ico"
    android:
      applicationId: "com.example.apple"
''';

    await runLegacy(yaml);
    await runPorted(yaml);

    final expected = generated(legacyProject);
    final actual = snapshot(workspace);

    expect(expected.keys, hasLength(5));
    expect(actual.keys.toSet(), expected.keys.toSet());
    for (final path in expected.keys) {
      expect(actual[path], expected[path], reason: path);
    }
  });

  test('the ported processor leaves the project as it was', () async {
    final before = snapshot(portedProject);

    await runPorted(flavors);

    expect(snapshot(portedProject).keys, before.keys);
  });

  group('intentional differences', () {
    test('a missing source is a FileNotFoundException', () async {
      const yaml = '''
flavors:
  apple:
    app:
      name: "Apple"
      icon: "assets/missing.png"
    android:
      applicationId: "com.example.apple"
''';

      await expectLater(runLegacy(yaml), throwsA(isA<FileSystemException>()));
      await expectLater(runPorted(yaml), throwsA(isA<FileNotFoundException>()));
    });

    test('a source that is not an image is a MalformedResourceException, '
        'and nothing is left behind', () async {
      File(
        p.join(legacyProject.path, 'assets/apple.png'),
      ).writeAsBytesSync([1, 2, 3]);
      File(
        p.join(portedProject.path, 'assets/apple.png'),
      ).writeAsBytesSync([1, 2, 3]);
      const yaml = '''
flavors:
  banana:
    app:
      name: "Banana"
      icon: "assets/app.png"
    android:
      applicationId: "com.example.banana"
  apple:
    app:
      name: "Apple"
      icon: "assets/apple.png"
    android:
      applicationId: "com.example.apple"
''';

      await expectLater(runLegacy(yaml), throwsA(isA<FileNotFoundException>()));
      await expectLater(
        runPorted(yaml),
        throwsA(isA<MalformedResourceException>()),
      );

      expect(generated(legacyProject), isNotEmpty);
      expect(snapshot(workspace), isEmpty);
    });

    test('an animated source renders its first frame', () async {
      final first = img.Image(width: 32, height: 32, numChannels: 4)
        ..clear(img.ColorRgba8(255, 0, 0, 255));
      final second = img.Image(width: 32, height: 32, numChannels: 4)
        ..clear(img.ColorRgba8(0, 0, 255, 255));
      first.frameDuration = 100;
      second.frameDuration = 100;
      first.addFrame(second);
      final gif = img.encodeGif(first);
      createProject(portedProject, {'assets/apple.gif': gif});
      const yaml = '''
flavors:
  apple:
    app:
      name: "Apple"
      icon: "assets/apple.gif"
    android:
      applicationId: "com.example.apple"
''';

      await runPorted(yaml);

      final icon = img.decodePng(
        File(
          p.join(
            workspace.path,
            'android/app/src/apple/res/mipmap-mdpi/ic_launcher.png',
          ),
        ).readAsBytesSync(),
      )!;
      expect(icon.getPixel(10, 10).r, greaterThan(200));
      expect(icon.getPixel(10, 10).b, lessThan(60));
    });
  });
}
