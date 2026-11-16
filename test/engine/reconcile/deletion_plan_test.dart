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
import 'dart:io';

import 'package:flutter_flavorizr/src/engine/ownership.dart';
import 'package:flutter_flavorizr/src/engine/reconcile/deletion_plan.dart';
import 'package:flutter_flavorizr/src/engine/reconcile/stale_artifacts.dart';
import 'package:flutter_flavorizr/src/engine/shadow/file_digest.dart';
import 'package:flutter_flavorizr/src/engine/shadow/workspace_diff.dart';
import 'package:flutter_flavorizr/src/exception/unapproved_conflicts_exception.dart';
import 'package:flutter_test/flutter_test.dart';

import '../shadow/shadow_fixture.dart';

String hashOf(String content) => digestOf(utf8.encode(content));

StaleArtifact staleOf(
  String path,
  Ownership ownership, {
  String? recordedHash,
}) => StaleArtifact(
  processorId: 'android',
  path: path,
  ownership: ownership,
  recordedHash: recordedHash,
);

void main() {
  late ShadowFixture fixture;

  setUp(() => fixture = ShadowFixture());
  tearDown(() => fixture.dispose());

  Future<DeletionPlan> plan(
    List<StaleArtifact> stale, {
    List<String> paths = const ['android', 'lib'],
  }) => planDeletions(
    projectRoot: fixture.project.root,
    paths: paths,
    stale: stale,
  );

  group('planDeletions', () {
    test('a managed file nobody touched is deleted', () async {
      fixture.project.write('android/a.xml', 'generated');

      final result = await plan([
        staleOf(
          'android/a.xml',
          Ownership.managed,
          recordedHash: hashOf('generated'),
        ),
      ]);

      final change = result.changes.single;
      expect(change.path, 'android/a.xml');
      expect(change.kind, ChangeKind.deleted);
      expect(change.ownership, Ownership.managed);
      expect(change.disposition, ChangeDisposition.apply);
      expect(change.before, hashOf('generated'));
      expect(change.after, isNull);
    });

    test('a managed file edited by hand is a conflict', () async {
      fixture.project.write('android/a.xml', 'edited');

      final result = await plan([
        staleOf(
          'android/a.xml',
          Ownership.managed,
          recordedHash: hashOf('generated'),
        ),
      ]);

      expect(result.changes.single.disposition, ChangeDisposition.conflict);
    });

    test('a managed file with no recorded hash is a conflict', () async {
      fixture.project.write('android/a.xml', 'generated');

      final result = await plan([staleOf('android/a.xml', Ownership.managed)]);

      expect(result.changes.single.disposition, ChangeDisposition.conflict);
    });

    test('a scaffold whose hash still matches is deleted', () async {
      fixture.project.write('lib/main_dev.dart', 'template');

      final result = await plan([
        staleOf(
          'lib/main_dev.dart',
          Ownership.scaffold,
          recordedHash: hashOf('template'),
        ),
      ]);

      expect(result.changes.single.disposition, ChangeDisposition.apply);
    });

    test('a scaffold that changed goes through the conflict flow', () async {
      fixture.project.write('lib/main_dev.dart', 'my code');

      final result = await plan([
        staleOf(
          'lib/main_dev.dart',
          Ownership.scaffold,
          recordedHash: hashOf('template'),
        ),
      ]);

      expect(result.changes.single.disposition, ChangeDisposition.conflict);
    });

    test('a scaffold the lock cannot vouch for is never deleted silently', () async {
      fixture.project.write('lib/main_dev.dart', 'template');

      final result = await plan([
        staleOf('lib/main_dev.dart', Ownership.scaffold),
      ]);

      expect(result.changes.single.disposition, ChangeDisposition.conflict);
    });

    test('a patched file is released, never deleted', () async {
      fixture.project.write('android/build.gradle', 'user + regions');

      final result = await plan([
        staleOf(
          'android/build.gradle',
          Ownership.patched,
          recordedHash: hashOf('regions'),
        ),
      ]);

      expect(result.changes, isEmpty);
      expect(result.released.map((s) => s.path), ['android/build.gradle']);
    });

    test('a file that is already gone has nothing to delete', () async {
      final result = await plan([
        staleOf(
          'android/a.xml',
          Ownership.managed,
          recordedHash: hashOf('generated'),
        ),
      ]);

      expect(result.changes, isEmpty);
      expect(result.gone.map((s) => s.path), ['android/a.xml']);
    });

    test('a file outside the paths of the run is blocked', () async {
      fixture.project.write('ios/a.plist', 'generated');

      final result = await plan([
        staleOf(
          'ios/a.plist',
          Ownership.managed,
          recordedHash: hashOf('generated'),
        ),
      ]);

      expect(result.changes.single.disposition, ChangeDisposition.blocked);
    });

    test('a symbolic link is blocked and its target is left alone', () async {
      fixture.project.write('outside/secret.txt', 'secret');
      Link(
        fixture.project.abs('android/link.xml'),
      ).createSync(fixture.project.abs('outside/secret.txt'), recursive: true);

      final result = await plan([
        staleOf(
          'android/link.xml',
          Ownership.managed,
          recordedHash: hashOf('secret'),
        ),
      ]);

      expect(result.changes.single.disposition, ChangeDisposition.blocked);
      expect(fixture.project.read('outside/secret.txt'), 'secret');
    });

    test('a file behind a symbolic link folder is blocked', () async {
      fixture.project.write('outside/secret.txt', 'secret');
      Directory(fixture.project.abs('android')).createSync();
      Link(
        fixture.project.abs('android/dir'),
      ).createSync(fixture.project.abs('outside'));

      final result = await plan([
        staleOf(
          'android/dir/secret.txt',
          Ownership.managed,
          recordedHash: hashOf('secret'),
        ),
      ]);

      expect(result.changes.single.disposition, ChangeDisposition.blocked);
    });

    test('a folder is blocked', () async {
      Directory(fixture.project.abs('android/folder')).createSync(
        recursive: true,
      );

      final result = await plan([
        staleOf(
          'android/folder',
          Ownership.managed,
          recordedHash: hashOf('x'),
        ),
      ]);

      expect(result.changes.single.disposition, ChangeDisposition.blocked);
    });

    test('a path that leaves the project is rejected', () async {
      await expectLater(
        plan([staleOf('../outside.txt', Ownership.managed, recordedHash: 'h')]),
        throwsArgumentError,
      );
    });

    test('the changes are sorted by path', () async {
      fixture.project.write('android/b.xml', 'b');
      fixture.project.write('android/a.xml', 'a');

      final result = await plan([
        staleOf('android/b.xml', Ownership.managed, recordedHash: hashOf('b')),
        staleOf('android/a.xml', Ownership.managed, recordedHash: hashOf('a')),
      ]);

      expect(result.changes.map((c) => c.path), [
        'android/a.xml',
        'android/b.xml',
      ]);
    });
  });

  group('DeletionPlan.applyTo', () {
    test('adds the deletions to the diff of the shadow workspace', () async {
      fixture.project.write('android/a.xml', 'generated');
      fixture.project.write('android/b.xml', 'new');
      final shadow = await fixture.create(['android']);
      shadow.write('android/b.xml', 'changed');
      final diff = await shadow.diff();

      final result = await plan([
        staleOf(
          'android/a.xml',
          Ownership.managed,
          recordedHash: hashOf('generated'),
        ),
      ]);

      expect(result.applyTo(diff).changes.map((c) => c.path), [
        'android/a.xml',
        'android/b.xml',
      ]);
    });

    test('a path the diff already has is not deleted twice', () async {
      fixture.project.write('android/a.xml', 'generated');
      final shadow = await fixture.create(['android']);
      shadow.delete('android/a.xml');
      final diff = await shadow.diff();

      final result = await plan([
        staleOf(
          'android/a.xml',
          Ownership.managed,
          recordedHash: hashOf('generated'),
        ),
      ]);

      expect(result.applyTo(diff).changes, hasLength(1));
      expect(
        result.applyTo(diff).changes.single.disposition,
        ChangeDisposition.untracked,
      );
    });

    test('copy-back deletes what is clean and what was approved', () async {
      fixture.project.write('android/clean.xml', 'generated');
      fixture.project.write('android/edited.xml', 'edited');
      final shadow = await fixture.create(['android']);

      final result = await plan([
        staleOf(
          'android/clean.xml',
          Ownership.managed,
          recordedHash: hashOf('generated'),
        ),
        staleOf(
          'android/edited.xml',
          Ownership.managed,
          recordedHash: hashOf('generated'),
        ),
      ]);
      final diff = result.applyTo(await shadow.diff());

      expect(diff.conflicts.map((c) => c.path), ['android/edited.xml']);
      await expectLater(
        shadow.copyBack(diff),
        throwsA(isA<UnapprovedConflictsException>()),
      );
      expect(fixture.project.exists('android/clean.xml'), isTrue);

      await shadow.copyBack(diff, approvedConflicts: {'android/edited.xml'});

      expect(fixture.project.exists('android/clean.xml'), isFalse);
      expect(fixture.project.exists('android/edited.xml'), isFalse);
    });

    test('a kept conflict leaves the file alone', () async {
      fixture.project.write('android/edited.xml', 'edited');
      final shadow = await fixture.create(['android']);

      final result = await plan([
        staleOf(
          'android/edited.xml',
          Ownership.managed,
          recordedHash: hashOf('generated'),
        ),
      ]);
      final diff = result.applyTo(await shadow.diff());
      final kept = WorkspaceDiff([
        for (final change in diff.changes)
          change.withDisposition(ChangeDisposition.keep),
      ]);

      await shadow.copyBack(kept);

      expect(fixture.project.read('android/edited.xml'), 'edited');
    });
  });
}
