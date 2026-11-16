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

import 'package:flutter_flavorizr/src/engine/conflict/conflict_content.dart';
import 'package:flutter_flavorizr/src/engine/conflict/conflict_policy.dart';
import 'package:flutter_flavorizr/src/engine/conflict/conflict_terminal.dart';
import 'package:flutter_flavorizr/src/engine/conflict/unified_diff.dart';
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
    final conflicts = diff.conflicts;
    final paths = conflicts.map((change) => change.path).toList();

    if (paths.isEmpty) return ConflictResolution(approved: [], kept: []);

    switch (policy) {
      case ConflictPolicy.overwrite:
        return ConflictResolution(approved: paths, kept: []);
      case ConflictPolicy.keep:
        return ConflictResolution(approved: [], kept: paths);
      case null:
        if (yes || !terminal.isInteractive) {
          throw UnresolvedConflictsException(paths);
        }

        return _ask(conflicts);
    }
  }

  Future<ConflictResolution> _ask(List<FileChange> conflicts) async {
    final approved = <String>[];
    final kept = <String>[];

    for (var index = 0; index < conflicts.length; index++) {
      final change = conflicts[index];
      final choice = await _choose(change);

      switch (choice) {
        case _Choice.overwrite:
          approved.add(change.path);
        case _Choice.keep:
          kept.add(change.path);
        case _Choice.overwriteAll:
          approved.addAll(conflicts.skip(index).map((change) => change.path));

          return ConflictResolution(approved: approved, kept: kept);
        case null:
          // Nobody is left to answer, and a file nobody approved is never
          // written: fail, so that nothing is written at all.
          throw UnresolvedConflictsException(
            conflicts.skip(index).map((change) => change.path),
          );
      }
    }

    return ConflictResolution(approved: approved, kept: kept);
  }

  /// Asks what to do with [change] until the answer is understood. Returns
  /// `null` when the input ended.
  Future<_Choice?> _choose(FileChange change) async {
    final verb = change.kind == ChangeKind.deleted ? 'delete' : 'overwrite';

    terminal.write(
      '\n${change.path} was edited by hand and flavorizr wants to $verb it.\n',
    );

    while (true) {
      final answer = await terminal.readAnswer(_prompt);

      if (answer == null) return null;

      switch (answer.trim().toLowerCase()) {
        case 'o' || 'overwrite':
          return _Choice.overwrite;
        case 'k' || 'keep':
          return _Choice.keep;
        case 'a' || 'all':
          return _Choice.overwriteAll;
        case 'd' || 'diff':
          terminal.write(await _renderDiff(change));
        default:
          terminal.write('Please answer o, k, d or a.\n');
      }
    }
  }

  /// The diff from the file in the project to what the run would write, or a
  /// line saying why there is none to show.
  Future<String> _renderDiff(FileChange change) async {
    final current = await content.readCurrent(change.path) ?? const <int>[];
    final desired = await content.readDesired(change.path) ?? const <int>[];

    final currentText = _decode(current);
    final desiredText = _decode(desired);

    if (currentText == null || desiredText == null) {
      return 'Binary files differ.\n';
    }

    final diff = unifiedDiff(
      oldText: currentText,
      newText: desiredText,
      oldLabel: 'a/${change.path}',
      newLabel: 'b/${change.path}',
      color: terminal.supportsColor,
    );

    return diff.isEmpty
        ? 'No textual differences.\n'
        : '- your file   + what flavorizr would write\n$diff';
  }

  /// The text of [bytes] ready to be printed, or `null` when they are not text.
  ///
  /// The escape character is made visible: a file must not be able to send
  /// control sequences to the terminal of whoever reviews it.
  String? _decode(List<int> bytes) {
    try {
      final text = utf8.decode(bytes);

      return text.contains('\u0000') ? null : text.replaceAll('\x1B', '␛');
    } on FormatException {
      return null;
    }
  }
}

const _prompt = '[o]verwrite / [k]eep / [d]iff / overwrite [a]ll: ';

enum _Choice { overwrite, keep, overwriteAll }
