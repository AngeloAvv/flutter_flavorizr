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
import 'package:flutter_flavorizr/src/engine/conflict/conflict_content.dart';
import 'package:flutter_flavorizr/src/engine/conflict/conflict_resolver.dart';
import 'package:flutter_flavorizr/src/engine/lock/flavorizr_lock.dart';
import 'package:flutter_flavorizr/src/engine/reconcile/deletion_plan.dart';
import 'package:flutter_flavorizr/src/engine/reconcile/flavor_diff.dart';
import 'package:flutter_flavorizr/src/engine/reconcile/lock_update.dart';
import 'package:flutter_flavorizr/src/engine/reconcile/stale_artifacts.dart';
import 'package:flutter_flavorizr/src/engine/shadow/workspace_diff.dart';

/// What a run does to bring the project, and the lock, in line with the
/// configuration: the flavors that changed, the files to garbage collect and
/// the lock to write.
///
/// It is the piece the commit callback of `PlanExecutor` uses, in this order:
///
/// 1. [reconcile] computes it from the previous lock and what the run produced;
/// 2. [applyTo] adds the deletions to the diff of the shadow workspace;
/// 3. the conflicts of that diff are resolved and copied back, as for any other
///    change;
/// 4. [lockAfter] gives the lock to write once the copy-back succeeded.
final class Reconciliation {
  /// The flavors of the configuration against the ones the lock applied.
  final FlavorDiff flavors;

  /// The deletions garbage collection asks of the project.
  final DeletionPlan deletions;

  /// The paths of the lock that are not valid, and were ignored.
  final List<InvalidLockedPath> invalid;

  final FlavorizrLock? _previous;
  final String _flavorizrVersion;
  final Map<String, Iterable<Artifact>> _produced;
  final Map<String, String> _ownedHashes;
  final Map<String, Map<String, Set<String>>> _ownedObjects;
  final Map<String, Map<String, Map<String, String>>> _ownedKeys;
  final Map<String, String> _desiredFlavors;
  final Set<String> _availableProcessors;
  final List<StaleArtifact> _stale;
  final List<StaleArtifact> _unattributed;

  Reconciliation._({
    required this.flavors,
    required this.deletions,
    required this.invalid,
    required FlavorizrLock? previous,
    required String flavorizrVersion,
    required Map<String, Iterable<Artifact>> produced,
    required Map<String, String> ownedHashes,
    required Map<String, Map<String, Set<String>>> ownedObjects,
    required Map<String, Map<String, Map<String, String>>> ownedKeys,
    required Map<String, String> desiredFlavors,
    required Set<String> availableProcessors,
    required List<StaleArtifact> stale,
    required List<StaleArtifact> unattributed,
  }) : _previous = previous,
       _flavorizrVersion = flavorizrVersion,
       _produced = produced,
       _ownedHashes = ownedHashes,
       _ownedObjects = ownedObjects,
       _ownedKeys = ownedKeys,
       _desiredFlavors = desiredFlavors,
       _availableProcessors = availableProcessors,
       _stale = stale,
       _unattributed = unattributed;

  /// [diff], the changes of the shadow workspace, together with the deletions.
  WorkspaceDiff applyTo(WorkspaceDiff diff) => deletions.applyTo(diff);

  /// [inner] adjusted for the conflicts of the deletions: the shadow workspace
  /// still holds the stale files (nothing removes them there), so [inner] would
  /// serve one as the content the run wants, and the diff of a deletion would
  /// say that nothing changes. Pass the result to the `ConflictResolver`.
  ConflictContent conflictContent(ConflictContent inner) =>
      _DeletionAwareContent(inner, {
        for (final change in deletions.changes) change.path,
      });

  /// The lock to write once the copy-back of [diff] (the one [applyTo]
  /// returned) succeeded.
  ///
  /// Compute it *before* the copy-back and write it after: if it cannot be
  /// built (see `updateLock`) nothing has been changed yet.
  ///
  /// The files the run did not write or delete are not recorded as if it had:
  /// the ones [resolution] says to keep, the ones [diff] blocked and the stale
  /// ones nobody deleted (e.g. a processor removed them in the workspace on its
  /// own, which is never copied back). They keep what the lock had for them.
  FlavorizrLock lockAfter({
    required WorkspaceDiff diff,
    required ConflictResolution resolution,
  }) {
    final deleted = {
      for (final change in deletions.changes)
        if (diff.changes.any((c) => identical(c, change)) &&
            (change.disposition == ChangeDisposition.apply ||
                (change.disposition == ChangeDisposition.conflict &&
                    resolution.approved.contains(change.path))))
          change.path,
    };
    final dealtWith = {
      ...deleted,
      for (final stale in [...deletions.gone, ...deletions.released])
        stale.path,
    };

    return updateLock(
      previous: _previous,
      flavorizrVersion: _flavorizrVersion,
      produced: _produced,
      ownedHashes: _ownedHashes,
      ownedObjects: _ownedObjects,
      ownedKeys: _ownedKeys,
      desiredFlavors: _desiredFlavors,
      availableProcessors: _availableProcessors,
      stale: [..._stale, ..._unattributed],
      retained: {
        ...resolution.kept,
        ...diff.blocked.map((change) => change.path),
        // The run still tracks them, so nothing can say their record is gone.
        for (final entry in _unattributed) entry.path,
        for (final stale in _stale)
          if (!dealtWith.contains(stale.path)) stale.path,
      },
    );
  }

  /// The plan as text: the flavors that change (a rename is spelled out as a
  /// removal plus an addition), then what is deleted, and what is left in
  /// place.
  String render() {
    final sections = [
      flavors.render(),
      if (deletions.changes.isNotEmpty)
        'Files to delete:\n'
            '${deletions.changes.map((change) => change.describe()).join('\n')}',
      if (deletions.released.isNotEmpty)
        'Left in place (shared with you, no longer owned by flavorizr):\n'
            '${deletions.released.map((s) => '- ${s.path}').join('\n')}',
      if (invalid.isNotEmpty)
        'Ignored in the lock (not a path of the project):\n'
            '${invalid.map((i) => '- ${i.path} (${i.processorId})').join('\n')}',
    ];

    return sections.join('\n\n');
  }

  @override
  String toString() => render();
}

/// A [ConflictContent] that has no desired content for the paths that are
/// deleted.
final class _DeletionAwareContent implements ConflictContent {
  final ConflictContent _inner;
  final Set<String> _deleted;

  _DeletionAwareContent(this._inner, this._deleted);

  @override
  Future<List<int>?> readCurrent(String path) => _inner.readCurrent(path);

  @override
  Future<List<int>?> readDesired(String path) async =>
      _deleted.contains(path) ? null : _inner.readDesired(path);
}

/// Computes the reconciliation of a run.
///
/// [produced] holds the artifacts each processor of the run tracked, by
/// processor id: its keys are the processors that ran, the only ones garbage
/// collection and the lock update ever look at. [ownedHashes] are the hashes of
/// the owned content of the hashed ones, by canonical path. [ownedObjects] are
/// the UUIDs of the pbxproj objects each processor owns
/// (`FlavorizrContext.ownedObjects`), and [ownedKeys] the hash of each key they
/// own in a file (`FlavorizrContext.ownedKeys`): the lock records both. [tracked] is every
/// artifact the run tracked, whoever it is attributed to
/// (`FlavorizrContext.tracked`): a resource may track one from its teardown, on
/// the context of the run, and nothing the run tracks is garbage collected.
///
/// [desiredFlavors] maps each flavor of the configuration to the hash of its
/// resolved configuration, and is compared with the flavors of [previous];
/// [availableProcessors] are the ids of every processor, to tell a full run
/// from a partial one. [projectRoot] is the real project and [paths] the paths
/// the shadow workspace of the run covers (`ShadowWorkspace.paths`): nothing
/// outside of them is ever deleted. [hasher] hashes the owned content of a
/// file, like the one of `ShadowWorkspace.diff`.
///
/// Nothing is written: see [Reconciliation].
Future<Reconciliation> reconcile({
  required Directory projectRoot,
  required Iterable<String> paths,
  required FlavorizrLock? previous,
  required Map<String, Iterable<Artifact>> produced,
  required Iterable<Artifact> tracked,
  required Map<String, String> ownedHashes,
  Map<String, Map<String, Set<String>>> ownedObjects = const {},
  Map<String, Map<String, Map<String, String>>> ownedKeys = const {},
  required Map<String, String> desiredFlavors,
  required Set<String> availableProcessors,
  required String flavorizrVersion,
  ArtifactHasher? hasher,
}) async {
  final scan = findStaleArtifacts(
    previous: previous,
    produced: produced,
    tracked: tracked,
  );
  final deletions = await planDeletions(
    projectRoot: projectRoot,
    paths: paths,
    stale: scan.stale,
    hasher: hasher,
  );

  return Reconciliation._(
    flavors: diffFlavors(
      desired: desiredFlavors,
      applied: previous?.flavors ?? const {},
    ),
    deletions: deletions,
    invalid: scan.invalid,
    previous: previous,
    flavorizrVersion: flavorizrVersion,
    produced: produced,
    ownedHashes: ownedHashes,
    ownedObjects: ownedObjects,
    ownedKeys: ownedKeys,
    desiredFlavors: desiredFlavors,
    availableProcessors: availableProcessors,
    stale: scan.stale,
    unattributed: scan.unattributed,
  );
}
