/*
 * Copyright (c) 2024 Angelo Cassano
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
import 'dart:math' as math;

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import 'badge_source_icon.dart';

/// The files of a project on disk, as the choice of the source icon of a badge
/// reads them.
///
/// It reads headers, not images: the size of an icon is what it declares, and
/// nothing is decoded to know it.
class ProjectBadgeSourceFiles implements BadgeSourceFiles {
  /// The largest file looked at, in bytes: a bigger one is not an icon.
  static const maxBytes = 32 * 1024 * 1024;

  /// The root of the project, which every path is relative to.
  final Directory root;

  /// Reads the files of the project in [root].
  const ProjectBadgeSourceFiles(this.root);

  /// The file at [path], or `null` when it is not inside the project, links
  /// included, or cannot be resolved: a path of the configuration may be
  /// anything, and what is outside is not read. A link that stays inside the
  /// project is followed.
  File? _file(String path) {
    final resolved = p.normalize(p.join(root.path, path));

    if (!p.isWithin(p.normalize(root.path), resolved)) return null;

    try {
      // The check above is lexical: a link inside the project may lead out.
      final real = File(resolved).resolveSymbolicLinksSync();

      return p.isWithin(root.resolveSymbolicLinksSync(), real)
          ? File(real)
          : null;
    } on FileSystemException {
      return null;
    }
  }

  @override
  String? readText(String path) {
    final file = _file(path);

    if (file == null) return null;

    try {
      return file.existsSync() && file.lengthSync() <= maxBytes
          ? file.readAsStringSync()
          : null;
    } on FileSystemException {
      return null;
    } on FormatException {
      return null;
    }
  }

  @override
  int? imageSize(String path) {
    final file = _file(path);

    if (file == null) return null;

    try {
      if (!file.existsSync() || file.lengthSync() > maxBytes) return null;

      final bytes = file.readAsBytesSync();
      final info = img.findDecoderForData(bytes)?.startDecode(bytes);

      if (info == null || info.width <= 0 || info.height <= 0) return null;

      return math.min(info.width, info.height);
    } on FileSystemException {
      return null;
    } on Object {
      // The decoders signal damaged data with a variety of errors.
      return null;
    }
  }
}
