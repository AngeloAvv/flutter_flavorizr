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
  final Map<String, String> _desiredFlavors;
  final Set<String> _availableProcessors;
  final List<StaleArtifact> _stale;

  Reconciliation._({
    required this.flavors,
    required this.deletions,
    required this.invalid,
    required FlavorizrLock? previous,
    required String flavorizrVersion,
    required Map<String, Iterable<Artifact>> produced,
    required Map<String, String> ownedHashes,
    required Map<String, String> desiredFlavors,
    required Set<String> availableProcessors,
    required List<StaleArtifact> stale,
  }) : _previous = previous,
       _flavorizrVersion = flavorizrVersion,
       _produced = produced,
       _ownedHashes = ownedHashes,
       _desiredFlavors = desiredFlavors,
       _availableProcessors = availableProcessors,
       _stale = stale;

  /// [diff], the changes of the shadow workspace, together with the deletions.
  WorkspaceDiff applyTo(WorkspaceDiff diff) => deletions.applyTo(diff);

  /// The lock to write after the run, once the copy-back of [diff] (the one
  /// [applyTo] returned) succeeded.
  ///
  /// The files the run did not write are not recorded as if it had: the ones
  /// [resolution] says to keep, and the ones [diff] blocked. They keep what the
  /// lock had for them.
  FlavorizrLock lockAfter({
    required WorkspaceDiff diff,
    required ConflictResolution resolution,
  }) => updateLock(
    previous: _previous,
    flavorizrVersion: _flavorizrVersion,
    produced: _produced,
    ownedHashes: _ownedHashes,
    desiredFlavors: _desiredFlavors,
    availableProcessors: _availableProcessors,
    stale: _stale,
    retained: {...resolution.kept, ...diff.blocked.map((c) => c.path)},
  );

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

/// Computes the reconciliation of a run.
///
/// [produced] holds the artifacts each processor of the run tracked, by
/// processor id: its keys are the processors that ran, the only ones garbage
/// collection and the lock update ever look at. [ownedHashes] are the hashes of
/// the owned content of the hashed ones, by canonical path.
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
  required Map<String, String> ownedHashes,
  required Map<String, String> desiredFlavors,
  required Set<String> availableProcessors,
  required String flavorizrVersion,
  ArtifactHasher? hasher,
}) async {
  final scan = findStaleArtifacts(previous: previous, produced: produced);
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
    desiredFlavors: desiredFlavors,
    availableProcessors: availableProcessors,
    stale: scan.stale,
  );
}
