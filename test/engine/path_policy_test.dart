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

/// Guards the path rule of the processor contract: processors resolve every
/// path from `ctx.root` or `ctx.projectRoot`, never from the working
/// directory.
void main() {
  List<File> sources(String directory) => Directory(directory)
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .toList(growable: false);

  String relative(File file) => p.relative(file.path);

  group('Path policy', () {
    test('no source of the package reads the working directory', () {
      final offenders = sources('lib')
          .where(
            (file) => file.readAsStringSync().contains('Directory.current'),
          )
          .map(relative);

      expect(offenders, isEmpty);
    });

    test('the engine never touches the K paths directly', () {
      final processors = p.join('lib', 'src', 'engine', 'processors');
      final offenders = sources(p.join('lib', 'src', 'engine'))
          .where((file) => !p.isWithin(processors, file.path))
          .where((file) => file.readAsStringSync().contains('constants.dart'))
          .map(relative);

      // K is only a catalogue of project relative paths: processors pass them
      // to the context, so the engine itself has no reason to import it. The
      // ported processors (`engine/processors`) are those consumers.
      expect(offenders, isEmpty);
    });
  });
}
