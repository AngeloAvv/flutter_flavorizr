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

import 'package:flutter_flavorizr/src/engine/shadow/shadow_workspace.dart';
import 'package:flutter_flavorizr/src/engine/shadow/workspace_paths.dart';

/// Where the two sides of a conflict are read from, to show a diff.
abstract interface class ConflictContent {
  /// The bytes of the file in the project now, or `null` when it does not exist
  /// (or cannot be read as a regular file).
  Future<List<int>?> readCurrent(String path);

  /// The bytes of the file as the run wants it, or `null` when the run deletes
  /// it.
  Future<List<int>?> readDesired(String path);
}

/// The [ConflictContent] of a [ShadowWorkspace]: the real project against the
/// workspace.
class ShadowConflictContent implements ConflictContent {
  final Directory _project;
  final Directory _shadow;

  /// Reads the conflicts of [workspace].
  ShadowConflictContent(ShadowWorkspace workspace)
    : _project = workspace.projectRoot,
      _shadow = workspace.root;

  @override
  Future<List<int>?> readCurrent(String path) => _read(_project, path);

  @override
  Future<List<int>?> readDesired(String path) => _read(_shadow, path);

  /// Reads a regular file below [root], never following a link: the diff must
  /// show what copy-back would actually write or replace.
  Future<List<int>?> _read(Directory root, String path) async {
    final canonical = canonicalPath(path);

    if (goesThroughLink(root, canonical)) return null;

    final file = resolveIn(root, canonical);

    if (await FileSystemEntity.type(file, followLinks: false) !=
        FileSystemEntityType.file) {
      return null;
    }

    return File(file).readAsBytes();
  }
}
