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

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../tool/parity/src/differ.dart';

void main() {
  late Directory golden;
  late Directory actual;

  setUp(() {
    final root = Directory.systemTemp.createTempSync('parity_differ_');
    golden = Directory(p.join(root.path, 'golden'))..createSync();
    actual = Directory(p.join(root.path, 'actual'))..createSync();
    addTearDown(() => root.deleteSync(recursive: true));
  });

  void write(Directory tree, String path, String content) {
    File(p.join(tree.path, path))
      ..createSync(recursive: true)
      ..writeAsStringSync(content);
  }

  group('compareTrees', () {
    test('identical trees are clean', () {
      write(golden, 'android/app/build.gradle', 'a\n');
      write(actual, 'android/app/build.gradle', 'a\n');

      final report = compareTrees(golden, actual);

      expect(report.differences, isEmpty);
      expect(report.isClean, isTrue);
    });

    test('reports a changed file with the lines that changed', () {
      write(golden, 'lib/main.dart', 'one\ntwo\nthree\n');
      write(actual, 'lib/main.dart', 'one\n2\nthree\n');

      final report = compareTrees(golden, actual);

      expect(report.isClean, isFalse);
      expect(report.differences, hasLength(1));
      final difference = report.differences.single;
      expect(difference.path, 'lib/main.dart');
      expect(difference.kind, DifferenceKind.changed);
      expect(difference.diff, '-two\n+2\n');
    });

    test('reports files that were added or removed', () {
      write(golden, 'removed.txt', 'x\n');
      write(actual, 'added.txt', 'y\n');

      final report = compareTrees(golden, actual);

      expect(
        {for (final d in report.differences) d.path: d.kind},
        {
          'added.txt': DifferenceKind.added,
          'removed.txt': DifferenceKind.removed,
        },
      );
    });

    test(
      'a whitelisted difference is reported with its reason but is clean',
      () {
        write(
          golden,
          'android/app/src/main/res/mipmap/ic_launcher.png.sha256',
          'old\n',
        );
        write(
          actual,
          'android/app/src/main/res/mipmap/ic_launcher.png.sha256',
          'new\n',
        );
        final whitelist = Whitelist.parse('''
- path: android/app/src/main/res/**
  reason: M5 removes the dummy assets on purpose
''');

        final report = compareTrees(golden, actual, whitelist: whitelist);

        expect(report.isClean, isTrue);
        expect(
          report.differences.single.reason,
          'M5 removes the dummy assets on purpose',
        );
      },
    );

    test('a whitelist entry does not hide differences in other files', () {
      write(golden, 'lib/main.dart', 'a\n');
      write(actual, 'lib/main.dart', 'b\n');
      final whitelist = Whitelist.parse('''
- path: android/**
  reason: unrelated
''');

      final report = compareTrees(golden, actual, whitelist: whitelist);

      expect(report.isClean, isFalse);
      expect(report.differences.single.reason, isNull);
    });
  });

  group('an only-comments whitelist entry', () {
    final whitelist = Whitelist.parse('''
- path: ios/Runner.xcodeproj/project.pbxproj
  only-comments: true
  reason: Ruby annotates it so
''');
    const pbxproj = 'ios/Runner.xcodeproj/project.pbxproj';

    test('tolerates a file that differs only in its annotations', () {
      write(golden, pbxproj, 'a = B /* Flutter/x.xcconfig */;\nc = D;\n');
      write(actual, pbxproj, 'a = B /* x.xcconfig */;\nc = D /* Runner */;\n');

      final report = compareTrees(golden, actual, whitelist: whitelist);

      expect(report.isClean, isTrue);
      expect(report.differences.single.reason, 'Ruby annotates it so');
    });

    test('does not hide a change beside the annotations', () {
      write(golden, pbxproj, 'a = B /* x */;\nc = D;\n');
      write(actual, pbxproj, 'a = B /* y */;\nc = E;\n');

      final report = compareTrees(golden, actual, whitelist: whitelist);

      expect(report.isClean, isFalse);
      expect(report.differences.single.reason, isNull);
    });

    test('does not hide an added file', () {
      write(actual, pbxproj, 'a = B;\n');

      final report = compareTrees(golden, actual, whitelist: whitelist);

      expect(report.isClean, isFalse);
    });

    test('does not hide a removed file', () {
      write(golden, pbxproj, 'a = B;\n');

      final report = compareTrees(golden, actual, whitelist: whitelist);

      expect(report.isClean, isFalse);
    });
  });

  group('Whitelist.parse', () {
    test('rejects an entry without a reason', () {
      expect(
        () => Whitelist.parse('- path: lib/main.dart\n'),
        throwsFormatException,
      );
    });

    test('rejects an entry with a blank reason', () {
      expect(
        () => Whitelist.parse('- path: lib/main.dart\n  reason: "  "\n'),
        throwsFormatException,
      );
    });
  });
}
