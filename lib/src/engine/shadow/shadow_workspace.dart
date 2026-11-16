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
        await for (final entity in Directory(
          source,
        ).list(followLinks: false)) {
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
