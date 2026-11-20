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
import 'dart:io';

import 'package:flutter_flavorizr/src/badge/badge_renderer.dart';
import 'package:flutter_flavorizr/src/badge/resolved_badge.dart';
import 'package:flutter_flavorizr/src/engine/artifact.dart';
import 'package:flutter_flavorizr/src/engine/flavorizr_context.dart';
import 'package:flutter_flavorizr/src/engine/processors/icon_source_loader.dart';
import 'package:flutter_flavorizr/src/engine/shadow/file_digest.dart';

/// The version of the way the icons are rendered, which is part of every inputs
/// hash (see [iconInputs]).
///
/// It is bumped when flavorizr changes the pixels it makes from the same inputs
/// on purpose (another resize, another band, another font), so that the icons
/// of a project are made again. It is **not** bumped for what a library does:
/// another version of `package:image` that encodes the same pixels to other
/// bytes is exactly what the inputs hash is there to ignore.
const iconRenderingVersion = 1;

/// The hash of everything one icon file is rendered from, to record in the lock
/// (see `ManagedArtifact.inputs`).
///
/// It is made of the digest of the bytes of the source image ([sourceDigest], see
/// [GeneratedIcons.sourceDigest]) and of every option the pixels depend on: the
/// [kind] of file (`png` or `ico`), the [sizes] of its frames, the [badge] and,
/// with one, the [area] it is drawn in. What it does not depend on is the path
/// of the source, the flavor or the machine, so it is the same everywhere for
/// the same icon, and a source that is renamed or moved with the same content
/// changes nothing. The output is never part of it.
String iconInputs({
  required String kind,
  required String sourceDigest,
  required Iterable<int> sizes,
  ResolvedBadge? badge,
  BadgeArea area = BadgeArea.full,
}) => digestOf(
  utf8.encode(
    jsonEncode({
      'rendering': iconRenderingVersion,
      'kind': kind,
      'source': sourceDigest,
      'sizes': sizes.toList(growable: false),
      // The area only matters with a band to draw in it.
      'badge': badge == null
          ? null
          : {'label': badge.label, 'color': badge.color.hex, 'area': area.name},
    }),
  ),
);

/// The files an icons processor generates in a run, and what it does about each
/// of them: leave it as it is when it was generated from the same inputs, or
/// write the bytes it rendered.
///
/// A processor asks [keepIfUpToDate] for a file before it renders it, so that
/// nothing is rendered for what is up to date, and calls [add] for the rest.
/// Nothing is written until [write], which a processor calls once everything is
/// rendered, so that a source that is missing or broken leaves the workspace as
/// it was.
final class GeneratedIcons {
  final FlavorizrContext _ctx;
  final Map<String, Future<String>> _digests = {};
  final Map<String, ({List<int>? bytes, String? inputs})> _files = {};

  /// Creates the files of the run of the processor [_ctx] is for.
  GeneratedIcons(this._ctx);

  /// The digest of the source image at [path], relative to the project.
  ///
  /// The image is read with the checks of `loadIconSource`, which throws what
  /// it does for a file that is missing, too big or outside the project, and
  /// once for every path: it is not decoded.
  Future<String> sourceDigest(String path) => _digests.putIfAbsent(
    path,
    () async => digestOf(await readIconSourceBytes(_ctx, path)),
  );

  /// Whether the file at [path] is up to date with [inputs]: it was generated
  /// from them and nobody changed it (see `FlavorizrContext.isGeneratedFrom`).
  ///
  /// It then stays as it is, and is declared with [inputs] when [write] is
  /// called. When it is not, the processor renders it and calls [add].
  Future<bool> keepIfUpToDate(String path, String inputs) async {
    if (!await _ctx.isGeneratedFrom(path, inputs)) return false;

    _files[path] = (bytes: null, inputs: inputs);

    return true;
  }

  /// Adds the file at [path] with the [bytes] the processor rendered, from
  /// [inputs] if it has any (a file that is cheap to make does not).
  void add(String path, List<int> bytes, {String? inputs}) =>
      _files[path] = (bytes: bytes, inputs: inputs);

  /// Writes what was added to the workspace and declares every file of the run,
  /// the ones kept as they are included, as [Artifact.managed].
  Future<void> write() async {
    for (final MapEntry(key: path, value: file) in _files.entries) {
      final bytes = file.bytes;

      if (bytes != null) {
        final target = File(_ctx.resolve(path));

        await target.parent.create(recursive: true);
        await target.writeAsBytes(bytes);
      }

      _ctx.track(Artifact.managed(path, inputs: file.inputs));
    }
  }
}
