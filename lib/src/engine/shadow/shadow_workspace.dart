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
///
/// Known limits: file permissions (e.g. an executable bit) are not preserved,
/// since files are written as new content; and the real-file check right before
/// the renames narrows, but cannot close, the window in which another process
/// may write to the project.
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
      try {
        await temporary.delete(recursive: true);
      } on FileSystemException {
        // Do not hide the error that made the copy fail.
      }

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

  /// Creates a workspace, runs [body] with it and deletes it afterwards,
  /// whether [body] returns or throws.
  ///
  /// This is the way to use a workspace: the temporary directory never outlives
  /// the run, and a failure inside [body], such as a failing processor, leaves
  /// the real project untouched since it is never written before
  /// [copyBack].
  static Future<T> run<T>({
    required Directory projectRoot,
    required Iterable<String> paths,
    required Future<T> Function(ShadowWorkspace shadow) body,
    Directory? tempParent,
  }) async {
    final shadow = await create(
      projectRoot: projectRoot,
      paths: paths,
      tempParent: tempParent,
    );

    try {
      return await body(shadow);
    } finally {
      try {
        await shadow.dispose();
      } on FileSystemException {
        // A leftover temporary directory must not hide what [body] threw.
      }
    }
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
  /// `--overwrite-scaffold` flag. A file in [edited] was found edited by hand
  /// by the processor that owns part of it: writing it is a conflict, whatever
  /// its hash says. A change to a file nobody tracked is
  /// reported as untracked and is never copied back.
  Future<WorkspaceDiff> diff({
    Iterable<Artifact> tracked = const [],
    Map<String, String> recordedHashes = const {},
    bool overwriteScaffold = false,
    Set<String> edited = const {},
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
    final scan = await _scanShadow();
    final current = scan.files;
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
          // A file outside the whitelist was never copied, so there is no
          // baseline to tell whether the real one changed: it is not written.
          // Neither is a file a processor replaced with a link: it did not
          // delete it.
          disposition: !_isWhitelisted(path) || _isUnderLink(path, scan.links)
              ? ChangeDisposition.blocked
              : artifact == null
              ? ChangeDisposition.untracked
              : await _judge(
                  artifact: artifact,
                  kind: kind,
                  recordedHash: recorded[path],
                  overwriteScaffold: overwriteScaffold,
                  hashOwned: hashOwned,
                  edited: edited.map(canonicalPath).contains(path),
                ),
          before: before,
          after: after,
        ),
      );
    }

    return WorkspaceDiff(changes);
  }

  bool _isWhitelisted(String path) => paths.any(
    (allowed) => allowed == path || p.posix.isWithin(allowed, path),
  );

  bool _isUnderLink(String path, Set<String> links) =>
      links.any((link) => link == path || p.posix.isWithin(link, path));

  Future<ChangeDisposition> _judge({
    required Artifact artifact,
    required ChangeKind kind,
    required String? recordedHash,
    required bool overwriteScaffold,
    required ArtifactHasher hashOwned,
    bool edited = false,
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
      ArtifactAction.overwrite ||
      ArtifactAction.patch when edited && exists => ChangeDisposition.conflict,
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
      Ownership.managed =>
        recordedHash != null && recordedHash == currentHash
            ? ChangeDisposition.apply
            : ChangeDisposition.conflict,
      // A patched file owns only some regions or keys, and the rest of the
      // file is the user's: removing it whole is never silent.
      Ownership.patched => ChangeDisposition.conflict,
    };
  }

  /// Scans the workspace: the digest of every file and the symbolic links, by
  /// canonical path. Ignored folders are left out. Links are never followed.
  Future<({Map<String, String> files, Set<String> links})> _scanShadow() async {
    final files = <String, String>{};
    final links = <String>{};

    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File && entity is! Link) continue;

      final relative = p.posix.joinAll(
        p.split(p.relative(entity.path, from: root.path)),
      );

      if (p.posix.split(relative).any(isIgnoredName)) continue;

      if (entity is Link) {
        links.add(relative);
      } else {
        files[relative] = digestOf(await (entity as File).readAsBytes());
      }
    }

    return (files: files, links: links);
  }

  /// Writes the changes of [diff] to the real project, all or nothing as far as
  /// the filesystem allows. See [copyBackChanges] for the guarantees.
  ///
  /// Only the changes that [diff] marks to apply are written, plus the
  /// conflicts whose path is in [approvedConflicts]. Throws a
  /// `ProjectChangedException` when a real file changed since it was copied,
  /// and an `UnapprovedConflictsException` for a conflict nobody approved.
  /// Both leave the project untouched.
  ///
  /// The folders a deletion leaves empty are removed too, below [paths] and
  /// never [paths] themselves: see `pruneBelow` of [copyBackChanges].
  ///
  /// Writes are atomic per file, not across files, and a process that edits a
  /// target in the few calls between its last check and its rename still loses
  /// that edit: there is no lock nor compare-and-swap to prevent it. See the
  /// known limit in [copyBackChanges].
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
    pruneBelow: paths,
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
        // Also when empty: a processor may write a new file into it.
        await Directory(resolveIn(shadowRoot, path)).create(recursive: true);
        await for (final entity in Directory(source).list(followLinks: false)) {
          final name = p.basename(entity.path);
          final child = '$path/$name';

          if (isIgnoredName(name)) continue;

          // The shadow may live inside the folder being copied (a temp parent
          // within the project): it must never be copied into itself.
          if (entity is Directory &&
              await FileSystemEntity.identical(entity.path, shadowRoot.path)) {
            continue;
          }

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
      case FileSystemEntityType.link:
      case FileSystemEntityType.notFound:
      case FileSystemEntityType.pipe:
      case FileSystemEntityType.unixDomainSock:
        // Nothing to copy: the path does not exist yet, or it is not a regular
        // file nor a folder.
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
