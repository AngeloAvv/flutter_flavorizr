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

import 'package:flutter_flavorizr/src/engine/artifact.dart';
import 'package:flutter_flavorizr/src/engine/lock/flavorizr_lock.dart';
import 'package:flutter_flavorizr/src/engine/ownership.dart';
import 'package:flutter_flavorizr/src/engine/reconcile/stale_artifacts.dart';
import 'package:flutter_test/flutter_test.dart';

FlavorizrLock lockOf(Map<String, ProcessorLock> processors) =>
    FlavorizrLock(flavorizrVersion: '3.0.0', processors: processors);

ProcessorLock filesOf(Map<String, LockedFile> files) =>
    ProcessorLock(files: files);

LockedFile managed(String hash) =>
    LockedFile(ownership: Ownership.managed, hash: hash);

StaleScan scanOf({
  required FlavorizrLock? previous,
  required Map<String, Iterable<Artifact>> produced,
  Iterable<Artifact>? tracked,
}) => findStaleArtifacts(
  previous: previous,
  produced: produced,
  // What the run tracked is at least what the processors produced.
  tracked: tracked ?? produced.values.expand((artifacts) => artifacts),
);

void main() {
  group('findStaleArtifacts', () {
    test('a file only the run tracked is not stale, and is reported', () {
      final scan = scanOf(
        previous: lockOf({
          'android': filesOf({'extra.txt': managed('h1')}),
        }),
        produced: {'android': const []},
        tracked: [const Artifact.managed('Extra.txt')],
      );

      expect(scan.stale, isEmpty);
      expect(scan.unattributed.map((s) => s.path), ['extra.txt']);
      expect(scan.unattributed.single.recordedHash, 'h1');
    });

    test('nothing is stale without a lock', () {
      final scan = scanOf(
        previous: null,
        produced: {
          'android': [const Artifact.managed('a.txt')],
        },
      );

      expect(scan.stale, isEmpty);
    });

    test('a file the processor did not produce again is stale', () {
      final scan = scanOf(
        previous: lockOf({
          'android': filesOf({
            'keep.txt': managed('h1'),
            'gone.txt': managed('h2'),
          }),
        }),
        produced: {
          'android': [const Artifact.managed('keep.txt')],
        },
      );

      expect(scan.stale.map((s) => s.path), ['gone.txt']);
      expect(scan.stale.single.processorId, 'android');
      expect(scan.stale.single.ownership, Ownership.managed);
      expect(scan.stale.single.recordedHash, 'h2');
    });

    test('a processor that ran and produced nothing loses everything', () {
      final scan = scanOf(
        previous: lockOf({
          'android': filesOf({'a.txt': managed('h1')}),
        }),
        produced: {'android': const []},
      );

      expect(scan.stale.map((s) => s.path), ['a.txt']);
    });

    test('the processors that did not run are never touched', () {
      final scan = scanOf(
        previous: lockOf({
          'android': filesOf({'android/a.txt': managed('h1')}),
          'ios': filesOf({'ios/b.txt': managed('h2')}),
        }),
        produced: {'android': const []},
      );

      expect(scan.stale.map((s) => s.path), ['android/a.txt']);
    });

    test('a path another ran processor produces now is not stale', () {
      final scan = scanOf(
        previous: lockOf({
          'old': filesOf({'shared.txt': managed('h1')}),
          'new': filesOf({}),
        }),
        produced: {
          'old': const [],
          'new': [const Artifact.managed('shared.txt')],
        },
      );

      expect(scan.stale, isEmpty);
    });

    test('a path a processor that did not run still owns is not stale', () {
      final scan = scanOf(
        previous: lockOf({
          'android': filesOf({'shared.txt': managed('h1')}),
          'ios': ProcessorLock(
            regions: {
              'shared.txt': {'region': 'h2'},
            },
          ),
        }),
        produced: {'android': const []},
      );

      expect(scan.stale, isEmpty);
    });

    test('paths are compared in canonical form', () {
      final scan = scanOf(
        previous: lockOf({
          'android': filesOf({'a/b.txt': managed('h1')}),
        }),
        produced: {
          'android': [const Artifact.managed('a/./c/../b.txt')],
        },
      );

      expect(scan.stale, isEmpty);
    });

    test('a path that only differs by case is not stale', () {
      // On a case-insensitive filesystem these are the same file, and deleting
      // the old spelling would delete what the run just wrote.
      final scan = scanOf(
        previous: lockOf({
          'android': filesOf({'Lib/A.dart': managed('h1')}),
        }),
        produced: {
          'android': [const Artifact.managed('lib/a.dart')],
        },
      );

      expect(scan.stale, isEmpty);
    });

    test('a path two processors of the run both owned is stale twice', () {
      final scan = scanOf(
        previous: lockOf({
          'a': filesOf({'shared.txt': managed('h1')}),
          'b': filesOf({'shared.txt': managed('h1')}),
        }),
        produced: {'a': const [], 'b': const []},
      );

      expect(scan.stale.map((s) => s.processorId), ['a', 'b']);
    });

    test('a path of the lock that leaves the project is never stale', () {
      final scan = scanOf(
        previous: lockOf({
          'android': filesOf({
            '../outside.txt': managed('h1'),
            '/etc/passwd': managed('h2'),
            'build/output.txt': managed('h3'),
          }),
        }),
        produced: {'android': const []},
      );

      expect(scan.stale, isEmpty);
      expect(scan.invalid.map((i) => i.path), [
        '../outside.txt',
        '/etc/passwd',
        'build/output.txt',
      ]);
      expect(scan.invalid.first.processorId, 'android');
    });
  });
}
