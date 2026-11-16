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
import 'package:flutter_flavorizr/src/engine/ownership_rules.dart';
import 'package:flutter_flavorizr/src/engine/shadow/copy_back.dart';
import 'package:flutter_flavorizr/src/engine/shadow/file_digest.dart';
import 'package:flutter_flavorizr/src/engine/shadow/workspace_diff.dart';
import 'package:flutter_flavorizr/src/engine/shadow/workspace_paths.dart';
import 'package:path/path.dart' as p;

/// A temporary copy of the parts of the project a run may touch.
///
/// Processors write to [root] (`FlavorizrContext.root`) instead of the real
/// project. The copy holds only the paths handed to [create], a whitelist of
/// known files and folders and never a whole platform folder, so build output
/// and caches (see [ignoredDirectoryNames]) are never copied. Symbolic links
/// are never followed: whatever is, or lives behind, a link is left out.
///
/// The workspace remembers the digest of every file at the moment it was
/// copied, which is what a later diff is computed against and what copy-back
/// checks the real project against.
class ShadowWorkspace {
  /// The real project the workspace was copied from.
  final Directory projectRoot;

  /// The shadow workspace, where processors write.
  final Directory root;

  /// The canonical paths of the whitelisted files and folders.
  final List<String> paths;

  final Map<String, String> _baseline;
  final List<String> _skippedLinks;

  ShadowWorkspace._({
    required this.projectRoot,
    required this.root,
    required this.paths,
    required Map<String, String> baseline,
    required List<String> skippedLinks,
  }) : _baseline = baseline,
       _skippedLinks = skippedLinks;

  /// Copies [paths], relative to [projectRoot], into a new temporary directory
  /// created below [tempParent], or below the system temporary directory when
  /// omitted.
  ///
  /// A path may be a file or a folder, which is copied recursively; a path
  /// that does not exist yet is accepted, since a processor may create it.
  /// Throws an [ArgumentError] for a path that is absolute, leaves the project
  /// or goes through an ignored folder.
  static Future<ShadowWorkspace> create({
    required Directory projectRoot,
    required Iterable<String> paths,
    Directory? tempParent,
  }) async {
    final whitelist = paths.map(canonicalPath).toSet().toList()..sort();
    final project = Directory(p.normalize(projectRoot.absolute.path));
    final temporary = await (tempParent ?? Directory.systemTemp).createTemp(
      'flavorizr_shadow_',
    );
    final shadowRoot = Directory(p.normalize(temporary.absolute.path));
    final baseline = <String, String>{};
    final skippedLinks = <String>[];

    try {
      for (final path in whitelist) {
        await _copyEntry(
          project: project,
          shadowRoot: shadowRoot,
          path: path,
          baseline: baseline,
          skippedLinks: skippedLinks,
        );
      }
    } on Object {
      await temporary.delete(recursive: true);

      rethrow;
    }

    return ShadowWorkspace._(
      projectRoot: project,
      root: shadowRoot,
      paths: List.unmodifiable(whitelist),
      baseline: Map.unmodifiable(baseline),
      skippedLinks: List.unmodifiable(skippedLinks),
    );
  }

  /// The canonical paths that were left out because they are, or live behind, a
  /// symbolic link.
  List<String> get skippedLinks => _skippedLinks;

  /// The digest of every file at the moment it was copied, by canonical path.
  Map<String, String> get baseline => _baseline;

  /// Computes what processors changed in the workspace, against the files as
  /// they were when it was copied.
  ///
  /// Every change is judged with the ownership rules of its artifact (see
  /// `decideArtifactAction`), where [tracked] are the artifacts processors
  /// declared and [recordedHashes] the hashes in the lock, by path. [hasher]
  /// computes the hash of the owned content of a file, and defaults to the
  /// digest of the whole file. [overwriteScaffold] is the
  /// `--overwrite-scaffold` flag. A change to a file nobody tracked is
  /// reported as untracked and is never copied back.
  Future<WorkspaceDiff> diff({
    Iterable<Artifact> tracked = const [],
    Map<String, String> recordedHashes = const {},
    bool overwriteScaffold = false,
    ArtifactHasher? hasher,
  }) async {
    final artifacts = {
      for (final artifact in tracked) canonicalPath(artifact.path): artifact,
    };
    final recorded = {
      for (final entry in recordedHashes.entries)
        canonicalPath(entry.key): entry.value,
    };
    final hashOwned = hasher ?? (_, bytes) => digestOf(bytes);
    final current = await _scanShadow();
    final changes = <FileChange>[];

    for (final path in {..._baseline.keys, ...current.keys}) {
      final before = _baseline[path];
      final after = current[path];

      if (before == after) continue;

      final kind = before == null
          ? ChangeKind.added
          : after == null
          ? ChangeKind.deleted
          : ChangeKind.modified;
      final artifact = artifacts[path];

      changes.add(
        FileChange(
          path: path,
          kind: kind,
          ownership: artifact?.ownership,
          disposition: artifact == null
              ? ChangeDisposition.untracked
              : await _judge(
                  artifact: artifact,
                  kind: kind,
                  recordedHash: recorded[path],
                  overwriteScaffold: overwriteScaffold,
                  hashOwned: hashOwned,
                ),
          before: before,
          after: after,
        ),
      );
    }

    return WorkspaceDiff(changes);
  }

  Future<ChangeDisposition> _judge({
    required Artifact artifact,
    required ChangeKind kind,
    required String? recordedHash,
    required bool overwriteScaffold,
    required ArtifactHasher hashOwned,
  }) async {
    final path = canonicalPath(artifact.path);
    final real = File(resolveIn(projectRoot, path));

    if (goesThroughLink(projectRoot, path) ||
        await FileSystemEntity.type(real.path, followLinks: false) ==
            FileSystemEntityType.directory) {
      return ChangeDisposition.blocked;
    }

    final exists = await real.exists();
    final currentHash = exists
        ? hashOwned(artifact, await real.readAsBytes())
        : null;

    if (kind == ChangeKind.deleted) {
      return _judgeDeletion(
        ownership: artifact.ownership,
        exists: exists,
        currentHash: currentHash,
        recordedHash: recordedHash,
      );
    }

    final desired = hashOwned(
      artifact,
      await File(resolveIn(root, path)).readAsBytes(),
    );
    final state = exists
        ? ArtifactState.existing(
            currentHash: currentHash!,
            recordedHash: recordedHash,
            desiredHash: desired,
          )
        : ArtifactState.missing(
            recordedHash: recordedHash,
            desiredHash: desired,
          );

    return switch (decideArtifactAction(
      artifact.ownership,
      state,
      overwriteScaffold: overwriteScaffold,
    )) {
      ArtifactAction.create ||
      ArtifactAction.overwrite ||
      ArtifactAction.patch => ChangeDisposition.apply,
      ArtifactAction.skip => ChangeDisposition.keep,
      ArtifactAction.conflict => ChangeDisposition.conflict,
    };
  }

  /// The rules for a file the workspace deleted, which `decideArtifactAction`
  /// does not cover: a run removes what it owns, never what is the user's.
  ChangeDisposition _judgeDeletion({
    required Ownership ownership,
    required bool exists,
    required String? currentHash,
    required String? recordedHash,
  }) {
    if (!exists) return ChangeDisposition.keep;

    return switch (ownership) {
      Ownership.scaffold => ChangeDisposition.keep,
      Ownership.local => ChangeDisposition.apply,
      Ownership.managed || Ownership.patched =>
        recordedHash != null && recordedHash == currentHash
            ? ChangeDisposition.apply
            : ChangeDisposition.conflict,
    };
  }

  /// The digest of every file in the workspace, by canonical path. Ignored
  /// folders and links are left out.
  Future<Map<String, String>> _scanShadow() async {
    final files = <String, String>{};

    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;

      final relative = p.posix.joinAll(
        p.split(p.relative(entity.path, from: root.path)),
      );

      if (p.posix.split(relative).any(isIgnoredName)) continue;

      files[relative] = digestOf(await entity.readAsBytes());
    }

    return files;
  }

  /// Writes the changes of [diff] to the real project, all or nothing as far as
  /// the filesystem allows. See [copyBackChanges] for the guarantees.
  ///
  /// Only the changes that [diff] marks to apply are written, plus the
  /// conflicts whose path is in [approvedConflicts]. Throws a
  /// `ProjectChangedException` when a real file changed since it was copied,
  /// and an `UnapprovedConflictsException` for a conflict nobody approved.
  /// Both leave the project untouched.
  Future<CopyBackResult> copyBack(
    WorkspaceDiff diff, {
    Set<String> approvedConflicts = const {},
    CopyBackFiles files = const LocalCopyBackFiles(),
  }) => copyBackChanges(
    projectRoot: projectRoot,
    shadowRoot: root,
    diff: diff,
    approvedConflicts: approvedConflicts,
    files: files,
  );

  /// Deletes the workspace. It is safe to call it more than once.
  Future<void> dispose() async {
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  }

  static Future<void> _copyEntry({
    required Directory project,
    required Directory shadowRoot,
    required String path,
    required Map<String, String> baseline,
    required List<String> skippedLinks,
  }) async {
    if (goesThroughLink(project, path)) {
      skippedLinks.add(path);

      return;
    }

    final source = resolveIn(project, path);
    final type = await FileSystemEntity.type(source, followLinks: false);

    switch (type) {
      case FileSystemEntityType.file:
        await _copyFile(
          source: source,
          destination: resolveIn(shadowRoot, path),
          path: path,
          baseline: baseline,
        );
      case FileSystemEntityType.directory:
        await for (final entity in Directory(source).list(followLinks: false)) {
          final name = p.basename(entity.path);
          final child = '$path/$name';

          if (isIgnoredName(name)) continue;

          if (entity is Link) {
            skippedLinks.add(child);
            continue;
          }

          await _copyEntry(
            project: project,
            shadowRoot: shadowRoot,
            path: child,
            baseline: baseline,
            skippedLinks: skippedLinks,
          );
        }
      case _:
        return;
    }
  }

  static Future<void> _copyFile({
    required String source,
    required String destination,
    required String path,
    required Map<String, String> baseline,
  }) async {
    final bytes = await File(source).readAsBytes();
    final target = File(destination);

    await target.parent.create(recursive: true);
    await target.writeAsBytes(bytes);

    baseline[path] = digestOf(bytes);
  }
}
