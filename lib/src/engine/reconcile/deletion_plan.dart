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
import 'package:flutter_flavorizr/src/engine/reconcile/created_files.dart';
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
  ///
  /// A patched file flavorizr **created** is not here: it is in [changes], as
  /// long as the processor can say what the user may have changed (see
  /// [planDeletions]).
  final List<StaleArtifact> released;

  /// The files of [released] that flavorizr makes for a flavor but has no record
  /// of making: they were there before it (the user's, or made by 2.x, which
  /// `adopt` cannot tell from the user's). They stay, and the plan says that
  /// they are the user's to delete.
  final List<StaleArtifact> notMade;

  /// The stale files that do not exist in the project anymore: nothing to
  /// delete.
  final List<StaleArtifact> gone;

  /// Creates a plan.
  DeletionPlan({
    required Iterable<FileChange> changes,
    required Iterable<StaleArtifact> released,
    required Iterable<StaleArtifact> gone,
    Iterable<StaleArtifact> notMade = const [],
  }) : changes = List.unmodifiable(
         changes.toList()..sort((a, b) => a.path.compareTo(b.path)),
       ),
       released = List.unmodifiable(released),
       notMade = List.unmodifiable(notMade),
       gone = List.unmodifiable(gone);

  /// [stale], a file of [released], as a line of the plan.
  String describeReleased(StaleArtifact stale) => notMade.contains(stale)
      ? '${stale.path} (flavorizr did not make it: delete it yourself if you '
            'do not need it)'
      : stale.path;

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
/// A patched file is the user's, and is released, except one flavorizr
/// **created** (the lock has `createdHash` for it, see `recordCreated`) of which
/// [foreignReader] knows what is not owned: it is deleted like a managed one,
/// but what it is compared with is that part and not the owned content, which
/// the user, Xcode and Flutter may change without the file ceasing to be the one
/// flavorizr made. A file that still holds what was recorded is
/// [ChangeDisposition.apply]; one edited anywhere else is a
/// [ChangeDisposition.conflict], and the user decides.
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
  ForeignReader? Function(String path)? foreignReader,
}) async {
  final project = Directory(p.normalize(projectRoot.absolute.path));
  final whitelist = paths.map(canonicalPath).toList();
  final hashOwned = hasher ?? (_, bytes) => digestOf(bytes);
  final changes = <FileChange>[];
  final released = <StaleArtifact>[];
  final gone = <StaleArtifact>[];
  final notMade = <StaleArtifact>[];
  final deleting = <String>{};
  // A file some processor records as patched is shared with the user, whoever
  // else claims it as its own.
  final shared = {
    for (final artifact in stale)
      if (artifact.ownership == Ownership.patched)
        pathIdentity(canonicalPath(artifact.path)),
  };

  // ...unless flavorizr made it, and every record of it says so.
  final made =
      {
        for (final artifact in stale)
          if (artifact.ownership == Ownership.patched &&
              artifact.createdHash != null &&
              foreignReader?.call(canonicalPath(artifact.path)) != null)
            pathIdentity(canonicalPath(artifact.path)),
      }..removeWhere(
        (path) => stale.any(
          (artifact) =>
              pathIdentity(canonicalPath(artifact.path)) == path &&
              (artifact.ownership != Ownership.patched ||
                  artifact.createdHash == null),
        ),
      );

  for (final artifact in stale) {
    final path = canonicalPath(artifact.path);
    final isMade = made.contains(pathIdentity(path));

    if (!isMade &&
        (artifact.ownership == Ownership.patched ||
            artifact.ownership == Ownership.local ||
            shared.contains(pathIdentity(path)))) {
      released.add(artifact);

      if (artifact.ownership == Ownership.patched &&
          foreignReader?.call(path) != null) {
        notMade.add(artifact);
      }

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
        final unchanged = isMade
            ? foreignDigest(foreignReader!(path)!, bytes) ==
                  artifact.createdHash
            : recorded != null &&
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

  return DeletionPlan(
    changes: changes,
    released: released,
    gone: gone,
    notMade: notMade,
  );
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
