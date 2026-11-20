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

import 'dart:convert';

import 'package:flutter_flavorizr/src/engine/artifact.dart';
import 'package:flutter_flavorizr/src/engine/conflict/conflict_content.dart';
import 'package:flutter_flavorizr/src/engine/conflict/conflict_policy.dart';
import 'package:flutter_flavorizr/src/engine/conflict/conflict_resolver.dart';
import 'package:flutter_flavorizr/src/engine/lock/flavorizr_lock.dart';
import 'package:flutter_flavorizr/src/engine/ownership.dart';
import 'package:flutter_flavorizr/src/engine/reconcile/reconciliation.dart';
import 'package:flutter_flavorizr/src/engine/shadow/file_digest.dart';
import 'package:flutter_flavorizr/src/engine/shadow/shadow_workspace.dart';
import 'package:flutter_flavorizr/src/engine/shadow/workspace_diff.dart';
import 'package:test/test.dart';

import '../conflict/conflict_fakes.dart';
import '../shadow/shadow_fixture.dart';

String hashOf(String content) => digestOf(utf8.encode(content));

LockedFile scaffoldOf([String? content]) => LockedFile(
  ownership: Ownership.scaffold,
  hash: content == null ? null : hashOf(content),
);

const mainPath = 'lib/main.dart';
const mainSource = 'void main() {}';

typedef Commit = ({
  Reconciliation reconciliation,
  FlavorizrLock lock,
  WorkspaceDiff diff,
});

void main() {
  late ShadowFixture fixture;

  setUp(() => fixture = ShadowFixture());
  tearDown(() => fixture.dispose());

  FlavorizrLock lockOf(Map<String, LockedFile> files) => FlavorizrLock(
    flavorizrVersion: '3.0.0',
    processors: {'flutter:main': ProcessorLock(files: files)},
  );

  /// The commit of a run in which `flutter:main` ran and produced [produced],
  /// after [edit] changed its shadow workspace.
  Future<Commit> commit({
    FlavorizrLock? previous,
    List<Artifact> produced = const [],
    void Function(ShadowWorkspace shadow)? edit,
    ConflictPolicy policy = ConflictPolicy.overwrite,
  }) async {
    final shadow = await fixture.create(['lib']);

    edit?.call(shadow);

    final reconciliation = await reconcile(
      projectRoot: fixture.project.root,
      paths: shadow.paths,
      previous: previous,
      produced: {'flutter:main': produced},
      tracked: produced,
      ownedHashes: {
        for (final artifact in produced)
          if (shadow.exists(artifact.path))
            artifact.path: hashOf(shadow.read(artifact.path)),
      },
      desiredFlavors: const {},
      availableProcessors: {'flutter:main'},
      flavorizrVersion: '3.0.0',
    );
    final diff = reconciliation.applyTo(await shadow.diff(tracked: produced));
    final resolution = await ConflictResolver(
      terminal: FakeTerminal(isInteractive: false),
      content: reconciliation.conflictContent(ShadowConflictContent(shadow)),
      policy: policy,
    ).resolve(diff);
    final lock = reconciliation.lockAfter(diff: diff, resolution: resolution);

    await shadow.copyBack(
      resolution.applyTo(diff),
      approvedConflicts: resolution.approved,
    );

    return (reconciliation: reconciliation, lock: lock, diff: diff);
  }

  const scaffold = Artifact.scaffold(mainPath);

  group('a scaffold the run creates', () {
    test('is recorded with the hash of what was written', () async {
      final result = await commit(
        produced: [scaffold],
        edit: (shadow) => shadow.write(mainPath, mainSource),
      );

      expect(fixture.project.read(mainPath), mainSource);
      expect(
        result.lock.processors['flutter:main']!.files[mainPath],
        scaffoldOf(mainSource),
      );
    });
  });

  group('a scaffold that already exists', () {
    test('as the run would write it is recorded with that hash, which is how '
        'a lock of version 1 learns it', () async {
      fixture.project.write(mainPath, mainSource);

      final result = await commit(
        previous: lockOf({mainPath: scaffoldOf()}),
        produced: [scaffold],
        edit: (shadow) => shadow.write(mainPath, mainSource),
      );

      expect(result.diff.isEmpty, isTrue);
      expect(
        result.lock.processors['flutter:main']!.files[mainPath],
        scaffoldOf(mainSource),
      );
    });

    test('that the user wrote is kept, and recorded without a hash', () async {
      fixture.project.write(mainPath, 'my own main');

      final result = await commit(
        produced: [scaffold],
        edit: (shadow) => shadow.write(mainPath, mainSource),
      );

      expect(fixture.project.read(mainPath), 'my own main');
      expect(
        result.lock.processors['flutter:main']!.files[mainPath],
        scaffoldOf(),
      );
    });

    test('that the user edited keeps the hash of what was written', () async {
      fixture.project.write(mainPath, 'edited');

      final result = await commit(
        previous: lockOf({mainPath: scaffoldOf(mainSource)}),
        produced: [scaffold],
        edit: (shadow) => shadow.write(mainPath, mainSource),
      );

      expect(fixture.project.read(mainPath), 'edited');
      expect(
        result.lock.processors['flutter:main']!.files[mainPath],
        scaffoldOf(mainSource),
      );
    });
  });

  group('a scaffold that is not produced anymore', () {
    test('is deleted when it is as it was written', () async {
      fixture.project.write(mainPath, mainSource);

      final result = await commit(
        previous: lockOf({mainPath: scaffoldOf(mainSource)}),
      );

      final change = result.reconciliation.deletions.changes.single;

      expect(change.path, mainPath);
      expect(change.disposition, ChangeDisposition.apply);
      expect(fixture.project.exists(mainPath), isFalse);
      expect(result.lock.processors, isEmpty);
    });

    test('goes through the conflict flow when the user edited it', () async {
      fixture.project.write(mainPath, 'edited');

      final result = await commit(
        previous: lockOf({mainPath: scaffoldOf(mainSource)}),
        policy: ConflictPolicy.keep,
      );

      final change = result.reconciliation.deletions.changes.single;

      expect(change.disposition, ChangeDisposition.conflict);
      expect(fixture.project.read(mainPath), 'edited');
      expect(
        result.lock.processors['flutter:main']!.files[mainPath],
        scaffoldOf(mainSource),
      );
    });

    test(
      'goes through the conflict flow when the lock has no hash for it',
      () async {
        fixture.project.write(mainPath, mainSource);

        final result = await commit(previous: lockOf({mainPath: scaffoldOf()}));

        expect(
          result.reconciliation.deletions.changes.single.disposition,
          ChangeDisposition.conflict,
        );
      },
    );
  });
}
