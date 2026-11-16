@Tags(['parity'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../tool/parity/src/differ.dart';
import '../../tool/parity/src/runner.dart';

/// End-to-end: needs Flutter, the network and a few minutes.
///
///   flutter test --run-skipped -t parity
void main() {
  final runner = ParityRunner(
    fixture: File(p.join('tool', 'parity', 'fixtures', 'flavorizr.yaml')),
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

      expect(
        File(
          p.join(first.path, 'ios', 'Runner.xcodeproj', 'project.pbxproj'),
        ).existsSync(),
        isTrue,
        reason: 'the run must actually produce a project',
      );
      final report = compareTrees(first, second);
      expect(report.differences, isEmpty, reason: report.describe());
    },
    timeout: const Timeout(Duration(minutes: 20)),
  );
}
