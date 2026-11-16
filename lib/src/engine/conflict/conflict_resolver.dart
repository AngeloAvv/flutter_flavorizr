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

import 'package:flutter_flavorizr/src/engine/conflict/conflict_content.dart';
import 'package:flutter_flavorizr/src/engine/conflict/conflict_policy.dart';
import 'package:flutter_flavorizr/src/engine/conflict/conflict_terminal.dart';
import 'package:flutter_flavorizr/src/engine/shadow/workspace_diff.dart';
import 'package:flutter_flavorizr/src/exception/unresolved_conflicts_exception.dart';

/// What was decided about the conflicts of a [WorkspaceDiff].
final class ConflictResolution {
  /// The paths of the conflicts that may be overwritten (or deleted): what to
  /// pass as `approvedConflicts` to copy-back.
  final Set<String> approved;

  /// The paths of the conflicts the user chose to keep.
  ///
  /// Their files must stay untouched, and the lock must keep whatever it
  /// recorded for them: recording the hash of the content that was *not*
  /// written would hide the edit from the next run.
  final Set<String> kept;

  ConflictResolution({
    required Iterable<String> approved,
    required Iterable<String> kept,
  }) : approved = Set.unmodifiable(approved),
       kept = Set.unmodifiable(kept);
}

/// Decides, for every conflict of a diff, whether it may be overwritten.
///
/// The decision comes from, in order:
///
/// 1. the [policy] (`--on-conflict`), when given, whatever the terminal;
/// 2. nobody, when the run cannot ask, i.e. [yes] (`--yes`) or a terminal that
///    is not [ConflictTerminal.isInteractive]: it fails listing the conflicts.
///
/// Deletions are conflicts like any other: an artifact scheduled for removal
/// that the user changed is resolved by the same rules.
class ConflictResolver {
  /// Where to ask, and what to show.
  final ConflictTerminal terminal;

  /// Where the two sides of a conflict are read from, to show a diff.
  final ConflictContent content;

  /// The `--on-conflict` policy, or `null` to ask (on a terminal) or fail.
  final ConflictPolicy? policy;

  /// The `--yes` flag: never ask, even on a terminal.
  final bool yes;

  const ConflictResolver({
    required this.terminal,
    required this.content,
    this.policy,
    this.yes = false,
  });

  /// Resolves the conflicts of [diff].
  ///
  /// Throws an [UnresolvedConflictsException] when there are conflicts and no
  /// way to resolve them. Nothing is written either way: the result only says
  /// what copy-back may write.
  Future<ConflictResolution> resolve(WorkspaceDiff diff) async {
    final paths = diff.conflicts.map((change) => change.path).toList();

    if (paths.isEmpty) return ConflictResolution(approved: [], kept: []);

    switch (policy) {
      case ConflictPolicy.overwrite:
        return ConflictResolution(approved: paths, kept: []);
      case ConflictPolicy.keep:
        return ConflictResolution(approved: [], kept: paths);
      case null:
        throw UnresolvedConflictsException(paths);
    }
  }
}
