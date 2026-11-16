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

import 'package:path/path.dart' as p;

/// The names of the folders that are never copied into a shadow workspace, nor
/// copied back: build output, caches, dependency checkouts and links to them.
///
/// They are compared case-insensitively, wherever they appear in a path.
const ignoredDirectoryNames = {
  '.cxx',
  '.dart_tool',
  '.git',
  '.gradle',
  '.symlinks',
  'build',
  'ephemeral',
  'pods',
};

/// Whether [name], a single path segment, is an ignored folder.
bool isIgnoredName(String name) =>
    ignoredDirectoryNames.contains(name.toLowerCase());

/// Returns [path] in the canonical form used as key across the shadow
/// workspace: relative to the project, `/` separated and normalized, on every
/// platform.
///
/// Throws an [ArgumentError] when [path] is empty, absolute, leaves the project
/// or goes through an ignored folder.
String canonicalPath(String path) {
  final unified = path.replaceAll(r'\', '/');
  final normalized = p.posix.normalize(unified);

  if (unified.isEmpty ||
      normalized == '.' ||
      p.posix.isAbsolute(normalized) ||
      RegExp(r'^[A-Za-z]:').hasMatch(normalized) ||
      normalized == '..' ||
      normalized.startsWith('../')) {
    throw ArgumentError.value(
      path,
      'path',
      'must be a path inside the project',
    );
  }

  if (p.posix.split(normalized).any(isIgnoredName)) {
    throw ArgumentError.value(
      path,
      'path',
      'goes through an ignored folder (${ignoredDirectoryNames.join(', ')})',
    );
  }

  return normalized;
}

/// Resolves the canonical [path] below the directory [root], using the
/// separators of the current platform.
String resolveIn(Directory root, String path) =>
    p.joinAll([root.path, ...p.posix.split(path)]);

/// Whether [path], below [root], or any of its parents below [root], is a
/// symbolic link. Links are never followed: the workspace treats them as
/// outside of the project.
bool goesThroughLink(Directory root, String path) {
  var current = root.path;

  for (final segment in p.posix.split(path)) {
    current = p.join(current, segment);
    final type = FileSystemEntity.typeSync(current, followLinks: false);

    if (type == FileSystemEntityType.link) return true;
    if (type == FileSystemEntityType.notFound) return false;
  }

  return false;
}
