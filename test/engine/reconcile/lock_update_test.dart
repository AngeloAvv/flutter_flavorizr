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
import 'package:flutter_flavorizr/src/engine/lock/lock_codec.dart';
import 'package:flutter_flavorizr/src/engine/ownership.dart';
import 'package:flutter_flavorizr/src/engine/reconcile/lock_update.dart';
import 'package:flutter_flavorizr/src/engine/reconcile/stale_artifacts.dart';
import 'package:flutter_test/flutter_test.dart';

LockedFile managed(String hash) =>
    LockedFile(ownership: Ownership.managed, hash: hash);

FlavorizrLock lockOf({
  Map<String, String> flavors = const {},
  Map<String, ProcessorLock> processors = const {},
}) => FlavorizrLock(
  flavorizrVersion: '3.0.0',
  flavors: flavors,
  processors: processors,
);

FlavorizrLock update({
  FlavorizrLock? previous,
  Map<String, Iterable<Artifact>> produced = const {},
  Map<String, String> hashes = const {},
  Map<String, String> flavors = const {},
  Set<String> available = const {'android', 'ios'},
  Iterable<StaleArtifact> stale = const [],
  Set<String> retained = const {},
}) => updateLock(
  previous: previous,
  flavorizrVersion: '3.0.0',
  produced: produced,
  ownedHashes: hashes,
  desiredFlavors: flavors,
  availableProcessors: available,
  stale: stale,
  retained: retained,
);

void main() {
  group('updateLock', () {
    test('records every class the way the lock expects', () {
      final lock = update(
        produced: {
          'android': [
            const Artifact.managed('a.xml'),
            const Artifact.scaffold('main.dart'),
            const Artifact.patched('build.gradle'),
            const Artifact.local('.idea/run.xml'),
          ],
        },
        hashes: {'a.xml': 'h1', 'build.gradle': 'h2'},
        flavors: {'dev': 'f1'},
        available: {'android'},
      );

      expect(lock.flavorizrVersion, '3.0.0');
      expect(lock.flavors, {'dev': 'f1'});
      expect(lock.processors['android']!.files, {
        'a.xml': managed('h1'),
        'main.dart': LockedFile(ownership: Ownership.scaffold),
        'build.gradle': LockedFile(ownership: Ownership.patched, hash: 'h2'),
      });
    });

    test('a hashed artifact without a hash is refused', () {
      expect(
        () => update(
          produced: {
            'android': [const Artifact.managed('a.xml')],
          },
        ),
        throwsArgumentError,
      );
    });

    test('what a processor stopped producing leaves its record', () {
      final lock = update(
        previous: lockOf(
          processors: {
            'android': ProcessorLock(
              files: {'a.xml': managed('h1'), 'old.xml': managed('h2')},
            ),
          },
        ),
        produced: {
          'android': [const Artifact.managed('a.xml')],
        },
        hashes: {'a.xml': 'h1'},
      );

      expect(lock.processors['android']!.files.keys, ['a.xml']);
    });

    test('a processor that owns nothing anymore has no record', () {
      final lock = update(
        previous: lockOf(
          processors: {
            'android': ProcessorLock(files: {'a.xml': managed('h1')}),
          },
        ),
        produced: {'android': const []},
      );

      expect(lock.processors, isEmpty);
    });

    test('a partial run leaves the other processors and the flavors alone', () {
      final iosRecord = ProcessorLock(files: {'ios/a.plist': managed('h9')});
      final lock = update(
        previous: lockOf(
          flavors: {'dev': 'f1', 'prod': 'f2'},
          processors: {
            'android': ProcessorLock(files: {'android/a.xml': managed('h1')}),
            'ios': iosRecord,
          },
        ),
        produced: {
          'android': [const Artifact.managed('android/b.xml')],
        },
        hashes: {'android/b.xml': 'h3'},
        flavors: {'dev': 'f1'},
      );

      expect(lock.processors['ios'], same(iosRecord));
      expect(lock.processors['android']!.files.keys, ['android/b.xml']);
      expect(lock.flavors, {'dev': 'f1', 'prod': 'f2'});
    });

    test('a run of every processor records the desired flavors', () {
      final lock = update(
        previous: lockOf(flavors: {'dev': 'f1', 'prod': 'f2'}),
        produced: {'android': const [], 'ios': const []},
        flavors: {'dev': 'f1', 'beta': 'f3'},
      );

      expect(lock.flavors, {'dev': 'f1', 'beta': 'f3'});
    });

    test('without any processor available the run is not a full one', () {
      final lock = update(
        previous: lockOf(flavors: {'prod': 'f2'}),
        produced: {'android': const []},
        flavors: {'dev': 'f1'},
        available: const {},
      );

      expect(lock.flavors, {'prod': 'f2'});
    });

    test('a partial first run records no flavors', () {
      final lock = update(
        produced: {'android': const []},
        flavors: {'dev': 'f1'},
      );

      expect(lock.flavors, isEmpty);
    });

    test('a kept conflict keeps the hash the lock had', () {
      final lock = update(
        previous: lockOf(
          processors: {
            'android': ProcessorLock(files: {'a.xml': managed('old')}),
          },
        ),
        produced: {
          'android': [
            const Artifact.managed('a.xml'),
            const Artifact.managed('b.xml'),
          ],
        },
        hashes: {'a.xml': 'new', 'b.xml': 'new'},
        retained: {'a.xml', 'b.xml'},
      );

      // b.xml was not in the lock: nothing was ever written, nothing to record.
      expect(lock.processors['android']!.files, {'a.xml': managed('old')});
    });

    test('a deletion that did not happen keeps its record', () {
      final lock = update(
        previous: lockOf(
          processors: {
            'android': ProcessorLock(
              files: {'edited.xml': managed('h1'), 'gone.xml': managed('h2')},
            ),
          },
        ),
        produced: {'android': const []},
        stale: [
          const StaleArtifact(
            processorId: 'android',
            path: 'edited.xml',
            ownership: Ownership.managed,
            recordedHash: 'h1',
          ),
          const StaleArtifact(
            processorId: 'android',
            path: 'gone.xml',
            ownership: Ownership.managed,
            recordedHash: 'h2',
          ),
        ],
        retained: {'edited.xml'},
      );

      expect(lock.processors['android']!.files, {'edited.xml': managed('h1')});
    });

    test('a second identical run writes a byte identical lock', () {
      final first = update(
        produced: {
          'android': [
            const Artifact.managed('b.xml'),
            const Artifact.managed('a.xml'),
          ],
          'ios': [const Artifact.scaffold('z')],
        },
        hashes: {'a.xml': 'h1', 'b.xml': 'h2'},
        flavors: {'prod': 'f2', 'dev': 'f1'},
      );
      final second = update(
        previous: first,
        produced: {
          'ios': [const Artifact.scaffold('z')],
          'android': [
            const Artifact.managed('a.xml'),
            const Artifact.managed('b.xml'),
          ],
        },
        hashes: {'b.xml': 'h2', 'a.xml': 'h1'},
        flavors: {'dev': 'f1', 'prod': 'f2'},
      );

      expect(LockCodec.encode(second), LockCodec.encode(first));
    });
  });
}
