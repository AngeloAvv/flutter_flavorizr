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

import 'package:flutter_flavorizr/src/engine/artifact.dart';
import 'package:flutter_flavorizr/src/engine/ownership.dart';
import 'package:flutter_flavorizr/src/engine/reconcile/stale_artifacts.dart';
import 'package:flutter_flavorizr/src/engine/shadow/file_digest.dart';
import 'package:flutter_flavorizr/src/engine/shadow/workspace_diff.dart';
import 'package:flutter_flavorizr/src/engine/shadow/workspace_paths.dart';
import 'package:path/path.dart' as p;

/// The deletions garbage collection asks of the project.
///
/// They are [FileChange]s of kind [ChangeKind.deleted], so they go through the
/// same conflict resolution and copy-back as every other change of a run: see
/// [applyTo].
final class DeletionPlan {
  /// The deletions, sorted by path. Their disposition says what copy-back does:
  /// [ChangeDisposition.apply] is deleted, [ChangeDisposition.conflict] only
  /// when approved, [ChangeDisposition.blocked] never.
  final List<FileChange> changes;

  /// The stale files that are never deleted, because the file is shared: a
  /// *patched* file only has some owned parts, and the rest is the user's (the
  /// same goes for a file some other processor records as patched). They are
  /// left in place and the lock stops owning them.
  final List<StaleArtifact> released;

  /// The stale files that do not exist in the project anymore: nothing to
  /// delete.
  final List<StaleArtifact> gone;

  /// Creates a plan.
  DeletionPlan({
    required Iterable<FileChange> changes,
    required Iterable<StaleArtifact> released,
    required Iterable<StaleArtifact> gone,
  }) : changes = List.unmodifiable(
         changes.toList()..sort((a, b) => a.path.compareTo(b.path)),
       ),
       released = List.unmodifiable(released),
       gone = List.unmodifiable(gone);

  /// [diff], the changes of the shadow workspace, together with the deletions.
  ///
  /// A path [diff] already has keeps its change: the workspace says what
  /// happened to it, and a file is never judged twice.
  WorkspaceDiff applyTo(WorkspaceDiff diff) {
    final known = {for (final change in diff.changes) change.path};

    return WorkspaceDiff([
      ...diff.changes,
      for (final change in changes)
        if (!known.contains(change.path)) change,
    ]);
  }
}

/// Decides what happens to each [stale] file of the real project in
/// [projectRoot], without touching anything.
///
/// A deletion is [ChangeDisposition.apply] only when the file is exactly what
/// the lock recorded, i.e. [StaleArtifact.recordedHash] equals the hash of its
/// owned content (computed by [hasher], the digest of the whole file by
/// default). A managed file the user edited, and a scaffold that no longer
/// matches or that the lock has no hash for, are [ChangeDisposition.conflict]:
/// the conflict flow decides, and nothing is deleted without it.
///
/// A deletion is [ChangeDisposition.blocked] when it must never happen: the
/// path is not within one of the [paths] the run works on, it is or goes
/// through a symbolic link (links are never followed, so what they point at is
/// never reached), or it is not a regular file.
///
/// Throws an [ArgumentError] for a path that leaves the project.
Future<DeletionPlan> planDeletions({
  required Directory projectRoot,
  required Iterable<String> paths,
  required Iterable<StaleArtifact> stale,
  ArtifactHasher? hasher,
}) async {
  final project = Directory(p.normalize(projectRoot.absolute.path));
  final whitelist = paths.map(canonicalPath).toList();
  final hashOwned = hasher ?? (_, bytes) => digestOf(bytes);
  final changes = <FileChange>[];
  final released = <StaleArtifact>[];
  final gone = <StaleArtifact>[];
  final deleting = <String>{};
  // A file some processor records as patched is shared with the user, whoever
  // else claims it as its own.
  final shared = {
    for (final artifact in stale)
      if (artifact.ownership == Ownership.patched)
        pathIdentity(canonicalPath(artifact.path)),
  };

  for (final artifact in stale) {
    final path = canonicalPath(artifact.path);

    if (artifact.ownership == Ownership.patched ||
        artifact.ownership == Ownership.local ||
        shared.contains(pathIdentity(path))) {
      released.add(artifact);
      continue;
    }

    // Two processors may have owned the same file: it is deleted once.
    if (!deleting.add(pathIdentity(path))) continue;

    FileChange change(ChangeDisposition disposition, {String? before}) =>
        FileChange(
          path: path,
          kind: ChangeKind.deleted,
          ownership: artifact.ownership,
          disposition: disposition,
          before: before,
          after: null,
        );

    if (!_isWithin(whitelist, path) || goesThroughLink(project, path)) {
      changes.add(change(ChangeDisposition.blocked));
      continue;
    }

    final file = resolveIn(project, path);

    switch (await FileSystemEntity.type(file, followLinks: false)) {
      case FileSystemEntityType.notFound:
        gone.add(artifact);
      case FileSystemEntityType.file:
        final bytes = await File(file).readAsBytes();
        final recorded = artifact.recordedHash;
        final unchanged =
            recorded != null &&
            hashOwned(_artifactOf(artifact, path), bytes) == recorded;

        changes.add(
          change(
            unchanged ? ChangeDisposition.apply : ChangeDisposition.conflict,
            before: digestOf(bytes),
          ),
        );
      case FileSystemEntityType.directory:
      case FileSystemEntityType.link:
      case FileSystemEntityType.pipe:
      case FileSystemEntityType.unixDomainSock:
        // Never a regular file: nothing a run produced, so nothing to delete.
        changes.add(change(ChangeDisposition.blocked));
    }
  }

  return DeletionPlan(changes: changes, released: released, gone: gone);
}

bool _isWithin(List<String> whitelist, String path) => whitelist.any(
  (allowed) => allowed == path || p.posix.isWithin(allowed, path),
);

Artifact _artifactOf(StaleArtifact stale, String path) =>
    switch (stale.ownership) {
      Ownership.scaffold => Artifact.scaffold(path),
      Ownership.managed => Artifact.managed(path),
      Ownership.patched => Artifact.patched(path),
      Ownership.local => Artifact.local(path),
    };
