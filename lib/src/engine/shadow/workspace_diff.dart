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
import 'package:flutter_flavorizr/src/engine/ownership.dart';

/// Computes the hash of the *owned* content of [artifact] from the [bytes] of
/// the whole file.
///
/// The whole file is owned by managed artifacts, while patched artifacts own
/// only some regions or keys: this is the seam where that knowledge plugs in.
/// The default hashes the whole file.
typedef ArtifactHasher = String Function(Artifact artifact, List<int> bytes);

/// What happened to a file in the shadow workspace.
enum ChangeKind {
  /// The file did not exist when the workspace was copied.
  added,

  /// The file exists with different content.
  modified,

  /// The file existed when the workspace was copied and does not anymore.
  deleted,
}

/// What copy-back does with a [FileChange].
enum ChangeDisposition {
  /// The change is copied to the real project.
  apply,

  /// The ownership of the artifact says to leave the real file alone.
  keep,

  /// The real file was changed by hand and the change would lose it: it is
  /// copied only when explicitly approved.
  conflict,

  /// No processor tracked the file, so nobody declared to own it: it is never
  /// copied.
  untracked,

  /// The real path is, or goes through, a symbolic link or is not a regular
  /// file, or the file lies outside the paths the workspace was copied from: it
  /// is never written, whatever the approvals.
  blocked,
}

/// One difference between the shadow workspace and the real project.
final class FileChange {
  /// The path, relative to the project and `/` separated.
  final String path;

  /// What happened to the file in the workspace.
  final ChangeKind kind;

  /// The class of the artifact, or `null` when no processor tracked the file.
  final Ownership? ownership;

  /// What copy-back does with the change.
  final ChangeDisposition disposition;

  /// The digest of the file when the workspace was copied, or `null` when it
  /// did not exist.
  final String? before;

  /// The digest of the file in the workspace now, or `null` when it was
  /// deleted.
  final String? after;

  /// Creates a change.
  const FileChange({
    required this.path,
    required this.kind,
    required this.ownership,
    required this.disposition,
    required this.before,
    required this.after,
  });

  String get _symbol => switch (kind) {
    ChangeKind.added => '+',
    ChangeKind.modified => '~',
    ChangeKind.deleted => '-',
  };

  /// A one line description, as printed by [WorkspaceDiff.render].
  String describe() {
    final owner = ownership?.name ?? 'untracked';
    final note = switch (disposition) {
      ChangeDisposition.apply || ChangeDisposition.untracked => '',
      ChangeDisposition.keep => ' [kept]',
      ChangeDisposition.conflict => ' [conflict]',
      ChangeDisposition.blocked => ' [blocked]',
    };

    return '$_symbol $path ($owner)$note';
  }

  @override
  String toString() => 'FileChange(${describe()})';
}

/// The differences between a shadow workspace and the real project, sorted by
/// path.
final class WorkspaceDiff {
  /// Every change, sorted by path.
  final List<FileChange> changes;

  /// Creates a diff.
  WorkspaceDiff(Iterable<FileChange> changes)
    : changes = List.unmodifiable(
        changes.toList()..sort((a, b) => a.path.compareTo(b.path)),
      );

  /// Whether the workspace is identical to the real project.
  bool get isEmpty => changes.isEmpty;

  /// The changes copy-back would write without asking.
  List<FileChange> get toApply => _where(ChangeDisposition.apply);

  /// The changes that would lose hand written edits.
  List<FileChange> get conflicts => _where(ChangeDisposition.conflict);

  /// The changes to files nobody tracked.
  List<FileChange> get untracked => _where(ChangeDisposition.untracked);

  /// The changes that can never be written.
  List<FileChange> get blocked => _where(ChangeDisposition.blocked);

  /// Whether some change would lose hand written edits.
  bool get hasConflicts => conflicts.isNotEmpty;

  List<FileChange> _where(ChangeDisposition disposition) => List.unmodifiable(
    changes.where((change) => change.disposition == disposition),
  );

  /// The diff as text, one change per line, ready to be printed.
  String render() =>
      isEmpty ? 'No changes.' : changes.map((c) => c.describe()).join('\n');

  @override
  String toString() => render();
}
