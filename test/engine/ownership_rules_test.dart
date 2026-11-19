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

import 'package:flutter_flavorizr/src/engine/ownership.dart';
import 'package:flutter_flavorizr/src/engine/ownership_rules.dart';
import 'package:test/test.dart';

void main() {
  group('managed', () {
    test('is created when the file does not exist', () {
      expect(
        decideArtifactAction(
          Ownership.managed,
          const ArtifactState.missing(desiredHash: 'new'),
        ),
        ArtifactAction.create,
      );
    });

    test('is created again when the user deleted a recorded file', () {
      expect(
        decideArtifactAction(
          Ownership.managed,
          const ArtifactState.missing(recordedHash: 'old', desiredHash: 'new'),
        ),
        ArtifactAction.create,
      );
    });

    test('is a no-op when it already matches the desired content', () {
      expect(
        decideArtifactAction(
          Ownership.managed,
          const ArtifactState.existing(
            currentHash: 'same',
            recordedHash: 'same',
            desiredHash: 'same',
          ),
        ),
        ArtifactAction.skip,
      );
    });

    test('is overwritten when the config changed and nobody edited it', () {
      expect(
        decideArtifactAction(
          Ownership.managed,
          const ArtifactState.existing(
            currentHash: 'old',
            recordedHash: 'old',
            desiredHash: 'new',
          ),
        ),
        ArtifactAction.overwrite,
      );
    });

    test('conflicts when it was edited by hand', () {
      expect(
        decideArtifactAction(
          Ownership.managed,
          const ArtifactState.existing(
            currentHash: 'edited',
            recordedHash: 'old',
            desiredHash: 'new',
          ),
        ),
        ArtifactAction.conflict,
      );
    });

    test('is a no-op when the user made it match the desired content', () {
      expect(
        decideArtifactAction(
          Ownership.managed,
          const ArtifactState.existing(
            currentHash: 'new',
            recordedHash: 'old',
            desiredHash: 'new',
          ),
        ),
        ArtifactAction.skip,
      );
    });

    test('conflicts when an existing file differs and is not in the lock', () {
      expect(
        decideArtifactAction(
          Ownership.managed,
          const ArtifactState.existing(
            currentHash: 'unknown',
            desiredHash: 'new',
          ),
        ),
        ArtifactAction.conflict,
      );
    });
  });

  group('patched', () {
    test('is created when the file does not exist', () {
      expect(
        decideArtifactAction(
          Ownership.patched,
          const ArtifactState.missing(desiredHash: 'new'),
        ),
        ArtifactAction.create,
      );
    });

    test('is a no-op when the owned parts already match', () {
      expect(
        decideArtifactAction(
          Ownership.patched,
          const ArtifactState.existing(
            currentHash: 'same',
            recordedHash: 'same',
            desiredHash: 'same',
          ),
        ),
        ArtifactAction.skip,
      );
    });

    test('is patched, not overwritten, when the config changed', () {
      expect(
        decideArtifactAction(
          Ownership.patched,
          const ArtifactState.existing(
            currentHash: 'old',
            recordedHash: 'old',
            desiredHash: 'new',
          ),
        ),
        ArtifactAction.patch,
      );
    });

    test('conflicts when the owned parts were edited by hand', () {
      expect(
        decideArtifactAction(
          Ownership.patched,
          const ArtifactState.existing(
            currentHash: 'edited',
            recordedHash: 'old',
            desiredHash: 'new',
          ),
        ),
        ArtifactAction.conflict,
      );
    });

    test('is patched when the file exists but is not in the lock yet', () {
      // First adoption of a file the user already had, e.g. a build.gradle
      // without markers: only the owned parts are written, the rest is kept.
      expect(
        decideArtifactAction(
          Ownership.patched,
          const ArtifactState.existing(
            currentHash: 'unknown',
            desiredHash: 'new',
          ),
        ),
        ArtifactAction.patch,
      );
    });

    test('conflicts when the config is unchanged but the file was edited', () {
      expect(
        decideArtifactAction(
          Ownership.patched,
          const ArtifactState.existing(
            currentHash: 'edited',
            recordedHash: 'same',
            desiredHash: 'same',
          ),
        ),
        ArtifactAction.conflict,
      );
    });
  });

  group('local', () {
    test('is created when the file does not exist', () {
      expect(
        decideArtifactAction(
          Ownership.local,
          const ArtifactState.missing(desiredHash: 'new'),
        ),
        ArtifactAction.create,
      );
    });

    test('is silently regenerated when it exists, whatever it contains', () {
      for (final recordedHash in [null, 'old', 'edited']) {
        expect(
          decideArtifactAction(
            Ownership.local,
            ArtifactState.existing(
              currentHash: 'edited',
              recordedHash: recordedHash,
              desiredHash: 'new',
            ),
          ),
          ArtifactAction.overwrite,
          reason: 'recorded hash: $recordedHash',
        );
      }
    });

    test('is never a conflict, in any state', () {
      final states = [
        const ArtifactState.missing(desiredHash: 'new'),
        const ArtifactState.missing(recordedHash: 'old', desiredHash: 'new'),
        for (final current in ['old', 'edited', 'new'])
          for (final recorded in [null, 'old', 'new'])
            ArtifactState.existing(
              currentHash: current,
              recordedHash: recorded,
              desiredHash: 'new',
            ),
      ];

      for (final state in states) {
        expect(
          decideArtifactAction(Ownership.local, state),
          isNot(ArtifactAction.conflict),
        );
      }
    });
  });

  group('hashing', () {
    test('only managed and patched artifacts are hashed in the lock', () {
      expect(
        {
          for (final ownership in Ownership.values)
            if (ownership.isHashed) ownership,
        },
        {Ownership.managed, Ownership.patched},
      );
    });
  });

  group('re-running without a config change', () {
    // The file on disk is what the previous run produced: current, recorded
    // and desired hashes are all the same.
    const settled = ArtifactState.existing(
      currentHash: 'same',
      recordedHash: 'same',
      desiredHash: 'same',
    );

    for (final ownership in [
      Ownership.scaffold,
      Ownership.managed,
      Ownership.patched,
    ]) {
      test('is a no-op for ${ownership.name}', () {
        expect(decideArtifactAction(ownership, settled), ArtifactAction.skip);
      });
    }
  });

  group('scaffold', () {
    const missing = ArtifactState.missing(desiredHash: 'new');
    const existing = ArtifactState.existing(
      currentHash: 'edited',
      desiredHash: 'new',
    );

    test('is created when the file does not exist', () {
      expect(
        decideArtifactAction(Ownership.scaffold, missing),
        ArtifactAction.create,
      );
    });

    test('is never overwritten once it exists, even if it differs', () {
      expect(
        decideArtifactAction(Ownership.scaffold, existing),
        ArtifactAction.skip,
      );
    });

    test('is overwritten when the user forces it', () {
      expect(
        decideArtifactAction(
          Ownership.scaffold,
          existing,
          overwriteScaffold: true,
        ),
        ArtifactAction.overwrite,
      );
    });

    test('is left alone when forced but already identical', () {
      expect(
        decideArtifactAction(
          Ownership.scaffold,
          const ArtifactState.existing(
            currentHash: 'same',
            desiredHash: 'same',
          ),
          overwriteScaffold: true,
        ),
        ArtifactAction.skip,
      );
    });

    test('is created, not overwritten, when forced and missing', () {
      expect(
        decideArtifactAction(
          Ownership.scaffold,
          missing,
          overwriteScaffold: true,
        ),
        ArtifactAction.create,
      );
    });
  });
}
