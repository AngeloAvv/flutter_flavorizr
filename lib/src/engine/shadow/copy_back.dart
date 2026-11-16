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

import 'package:flutter_flavorizr/src/engine/shadow/file_digest.dart';
import 'package:flutter_flavorizr/src/engine/shadow/workspace_diff.dart';
import 'package:flutter_flavorizr/src/engine/shadow/workspace_paths.dart';
import 'package:flutter_flavorizr/src/exception/copy_back_interrupted_exception.dart';
import 'package:flutter_flavorizr/src/exception/project_changed_exception.dart';
import 'package:flutter_flavorizr/src/exception/unapproved_conflicts_exception.dart';
import 'package:path/path.dart' as p;

/// The two filesystem operations that change the real project during
/// copy-back, kept apart so that an interruption can be simulated.
abstract interface class CopyBackFiles {
  /// Moves the staged file [staged] over [target], atomically.
  Future<void> replace(String staged, String target);

  /// Deletes [target].
  Future<void> remove(String target);
}

/// The [CopyBackFiles] of the local filesystem.
class LocalCopyBackFiles implements CopyBackFiles {
  const LocalCopyBackFiles();

  @override
  Future<void> replace(String staged, String target) async {
    await File(staged).rename(target);
  }

  @override
  Future<void> remove(String target) async {
    await File(target).delete();
  }
}

/// What copy-back wrote to the project.
final class CopyBackResult {
  /// The changes written to the project, in the order they were written.
  final List<FileChange> applied;

  CopyBackResult(Iterable<FileChange> applied)
    : applied = List.unmodifiable(applied);
}

/// Writes the changes of [diff] from the shadow workspace [shadowRoot] to the
/// real project [projectRoot], all or nothing as far as the filesystem allows.
///
/// 1. Nothing is touched when some conflict is not in [approvedConflicts].
/// 2. Every file to write is first staged next to its target, so the real
///    files are not touched by anything that can fail for lack of space or
///    rights.
/// 3. The real files are compared once more with the digests they had when
///    they were copied, and the whole copy-back is abandoned if any differs.
/// 4. Staged files are moved over their targets, one atomic rename each. If
///    one fails, the staged files that are left are removed and a
///    [CopyBackInterruptedException] lists what was already applied.
///
/// A staged file lives in the folder of its target, which guarantees the rename
/// does not cross filesystems.
Future<CopyBackResult> copyBackChanges({
  required Directory projectRoot,
  required Directory shadowRoot,
  required WorkspaceDiff diff,
  Set<String> approvedConflicts = const {},
  CopyBackFiles files = const LocalCopyBackFiles(),
}) async {
  final unapproved = diff.conflicts
      .where((change) => !approvedConflicts.contains(change.path))
      .map((change) => change.path);

  if (unapproved.isNotEmpty) throw UnapprovedConflictsException(unapproved);

  final writes = diff.changes
      .where(
        (change) =>
            change.disposition == ChangeDisposition.apply ||
            (change.disposition == ChangeDisposition.conflict &&
                approvedConflicts.contains(change.path)),
      )
      .toList();

  await _ensureUnchanged(projectRoot, writes);

  final staged = <String, String>{};
  final createdDirectories = <Directory>[];

  Future<void> cleanUp({required bool directories}) async {
    for (final path in staged.values) {
      final file = File(path);

      if (file.existsSync()) await file.delete();
    }

    staged.clear();

    if (!directories) return;

    // Deepest first, so that parents are empty by the time they are tried.
    for (final directory in createdDirectories.reversed) {
      if (directory.existsSync() && directory.listSync().isEmpty) {
        await directory.delete();
      }
    }
  }

  try {
    var counter = 0;

    for (final change in writes) {
      if (change.kind == ChangeKind.deleted) continue;

      final bytes = await File(
        resolveIn(shadowRoot, change.path),
      ).readAsBytes();

      if (digestOf(bytes) != change.after) {
        throw StateError(
          '`${change.path}` changed in the shadow workspace after the diff '
          'was computed: compute the diff again.',
        );
      }

      final target = resolveIn(projectRoot, change.path);

      createdDirectories.addAll(await _createParents(target));

      final stagedFile = File(
        p.join(p.dirname(target), '.${p.basename(target)}.${counter++}.tmp'),
      );

      staged[change.path] = stagedFile.path;
      await stagedFile.writeAsBytes(bytes);
    }

    await _ensureUnchanged(projectRoot, writes);
  } on Object {
    await cleanUp(directories: true);

    rethrow;
  }

  final applied = <FileChange>[];

  for (final change in writes) {
    final target = resolveIn(projectRoot, change.path);

    try {
      if (change.kind == ChangeKind.deleted) {
        await files.remove(target);
      } else {
        await files.replace(staged[change.path]!, target);
      }

      applied.add(change);
    } on Object catch (error) {
      await cleanUp(directories: false);

      throw CopyBackInterruptedException(
        applied: applied.map((change) => change.path),
        pending: writes.skip(applied.length).map((change) => change.path),
        cause: error,
      );
    }
  }

  return CopyBackResult(applied);
}

/// Throws a [ProjectChangedException] when a file in [writes] is not the way
/// it was when it was copied.
Future<void> _ensureUnchanged(
  Directory projectRoot,
  List<FileChange> writes,
) async {
  final changed = <String>[];

  for (final change in writes) {
    if (!await _isUnchanged(projectRoot, change)) changed.add(change.path);
  }

  if (changed.isNotEmpty) throw ProjectChangedException(changed);
}

Future<bool> _isUnchanged(Directory projectRoot, FileChange change) async {
  if (goesThroughLink(projectRoot, change.path)) return false;

  final path = resolveIn(projectRoot, change.path);
  final type = await FileSystemEntity.type(path, followLinks: false);

  if (change.before == null) return type == FileSystemEntityType.notFound;

  return type == FileSystemEntityType.file &&
      digestOf(await File(path).readAsBytes()) == change.before;
}

/// Creates the missing folders above [target] and returns them in the order
/// they were created, outermost first.
Future<List<Directory>> _createParents(String target) async {
  final missing = <Directory>[];
  var directory = Directory(p.dirname(target));

  while (!await directory.exists()) {
    missing.insert(0, directory);
    directory = directory.parent;
  }

  for (final directory in missing) {
    await directory.create();
  }

  return missing;
}
