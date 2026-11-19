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

import 'package:test/test.dart';
import 'package:path/path.dart' as p;

import '../../tool/parity/src/tree.dart';

void main() {
  late Directory source;
  late Directory destination;

  setUp(() {
    final root = Directory.systemTemp.createTempSync('parity_tree_');
    source = Directory(p.join(root.path, 'source'))..createSync();
    destination = Directory(p.join(root.path, 'destination'));
    addTearDown(() => root.deleteSync(recursive: true));
  });

  void write(String path, Object content) {
    final file = File(p.join(source.path, path))..createSync(recursive: true);
    content is String
        ? file.writeAsStringSync(content)
        : file.writeAsBytesSync(content as List<int>);
  }

  String read(String path) =>
      File(p.join(destination.path, path)).readAsStringSync();

  bool exists(String path) => File(p.join(destination.path, path)).existsSync();

  group('normalizeTree', () {
    test('copies text files, normalizing their content', () {
      write('android/app/build.gradle', 'built 2026-11-16T10:20:30Z\n');

      normalizeTree(source, destination);

      expect(read('android/app/build.gradle'), 'built <TIMESTAMP>\n');
    });

    test('replaces binary files with a sha256 marker', () {
      // A PNG signature is not valid UTF-8.
      write('ios/Runner/icon.png', [0x89, 0x50, 0x4E, 0x47, 0xFF, 0xFE]);

      normalizeTree(source, destination);

      expect(exists('ios/Runner/icon.png'), isFalse);
      // Computed independently with `shasum -a 256`.
      expect(
        read('ios/Runner/icon.png.sha256'),
        '694ada1b90ede5cedfebfa1dd642b37a0091c317fbe2b2148ebdb2c6662c30b2\n',
      );
    });

    test('skips .gitignore files, which would hide the golden files', () {
      write('.gitignore', '.idea\n');
      write('android/.gitignore', 'gradlew\n');
      write('android/gradlew', '#!/bin/sh\n');

      normalizeTree(source, destination);

      expect(exists('.gitignore'), isFalse);
      expect(exists('android/.gitignore'), isFalse);
      expect(exists('android/gradlew'), isTrue);
    });

    test('an ignored folder only matches whole path segments', () {
      write('ios/Flutter/ephemeral/x.env', 'x\n');
      write('ios/Flutter/not_ephemeral/y.env', 'y\n');

      normalizeTree(source, destination);

      expect(exists('ios/Flutter/ephemeral/x.env'), isFalse);
      expect(exists('ios/Flutter/not_ephemeral/y.env'), isTrue);
    });

    test('skips environment-dependent files', () {
      write('ios/Flutter/Generated.xcconfig', 'FLUTTER_ROOT=/Users/someone\n');
      write('ios/Flutter/ephemeral/flutter_native_integration.env', 'x\n');
      write('android/local.properties', 'flutter.sdk=/Users/someone\n');
      write('.dart_tool/package_config.json', '{}\n');
      write('pubspec.lock', 'packages:\n');
      write('android/app/build.gradle', 'kept\n');

      normalizeTree(source, destination);

      expect(exists('ios/Flutter/Generated.xcconfig'), isFalse);
      expect(
        exists('ios/Flutter/ephemeral/flutter_native_integration.env'),
        isFalse,
      );
      expect(exists('android/local.properties'), isFalse);
      expect(exists('.dart_tool/package_config.json'), isFalse);
      expect(exists('pubspec.lock'), isFalse);
      expect(exists('android/app/build.gradle'), isTrue);
    });
  });
}
