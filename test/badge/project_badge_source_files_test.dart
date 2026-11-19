/*
 * Copyright (c) 2024 Angelo Cassano
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

import 'package:flutter_flavorizr/src/badge/project_badge_source_files.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../engine/processors/android/android_icon_source_test.dart'
    show gradientPng;

void main() {
  late Directory temp;
  late Directory project;
  late ProjectBadgeSourceFiles files;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('flavorizr_badge_files_');
    addTearDown(() => temp.deleteSync(recursive: true));

    project = Directory(p.join(temp.path, 'project'))..createSync();
    files = ProjectBadgeSourceFiles(project);

    File(p.join(project.path, 'assets/inside.png'))
      ..createSync(recursive: true)
      ..writeAsBytesSync(gradientPng(600, 400));
    File(
      p.join(temp.path, 'outside.png'),
    ).writeAsBytesSync(gradientPng(800, 800));
    File(p.join(temp.path, 'outside.json')).writeAsStringSync('{}');
    File(p.join(project.path, 'assets/inside.json')).writeAsStringSync('{}');
  });

  group('ProjectBadgeSourceFiles', () {
    test('reads the size and the text of a file of the project', () {
      expect(files.imageSize('assets/inside.png'), 400);
      expect(files.readText('assets/inside.json'), '{}');
      expect(files.imageSize('assets/missing.png'), isNull);
    });

    test('reads nothing outside of the project', () {
      expect(files.imageSize('../outside.png'), isNull);
      expect(files.readText('../outside.json'), isNull);
    });

    test('reads nothing that a link of the project leads outside to', () {
      Link(
        p.join(project.path, 'assets/link.png'),
      ).createSync(p.join(temp.path, 'outside.png'));
      Link(
        p.join(project.path, 'assets/link.json'),
      ).createSync(p.join(temp.path, 'outside.json'));

      expect(files.imageSize('assets/link.png'), isNull);
      expect(files.readText('assets/link.json'), isNull);
    });

    test('follows a link that stays inside the project', () {
      Link(
        p.join(project.path, 'assets/alias.png'),
      ).createSync(p.join(project.path, 'assets/inside.png'));

      expect(files.imageSize('assets/alias.png'), 400);
    });
  });
}
