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

@Tags(['parity'])
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:path/path.dart' as p;

import '../../tool/parity/src/differ.dart';
import '../../tool/parity/src/runner.dart';

/// End-to-end: needs Flutter, the network and a few minutes.
///
///   dart test --run-skipped -t parity
void main() {
  final runner = ParityRunner(
    fixture: File(p.join('tool', 'parity', 'fixtures', 'flavorizr.yaml')),
    fixtureFiles: Directory(p.join('tool', 'parity', 'fixtures', 'files')),
  );
  const reference = FlavorizrSource('2.6.0');

  test(
    'two consecutive 2.6.0 runs produce identical normalized output',
    () async {
      final first = Directory.systemTemp.createTempSync('parity_first_');
      final second = Directory.systemTemp.createTempSync('parity_second_');
      addTearDown(() {
        first.deleteSync(recursive: true);
        second.deleteSync(recursive: true);
      });

      await runner.run(reference, first);
      await runner.run(reference, second);

      // The Firebase build phase gets a brand new random UUID on every run
      // (darwin_add_firebase_build_phase_processor.dart): the run must
      // exercise it, or the test would pass without proving anything.
      final pbxproj = File(
        p.join(first.path, 'ios', 'Runner.xcodeproj', 'project.pbxproj'),
      );
      expect(
        pbxproj.existsSync() ? pbxproj.readAsStringSync() : '',
        contains('Firebase Setup'),
        reason: 'the run must produce a Firebase build phase',
      );
      final report = compareTrees(first, second);
      expect(report.differences, isEmpty, reason: report.describe());
    },
    timeout: const Timeout(Duration(minutes: 20)),
  );
}
