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
import 'package:flutter_flavorizr/src/engine/flavorizr_context.dart';
import 'package:flutter_flavorizr/src/engine/flavorizr_processor.dart';
import 'package:flutter_flavorizr/src/engine/processors/android/bom_text_file.dart';
import 'package:flutter_flavorizr/src/exception/file_not_found_exception.dart';

/// A processor that patches one source file of the Linux runner.
///
/// The file belongs to the user: it is an [Artifact.patched] artifact and the
/// only part flavorizr owns is its marked regions (see `MarkedText`). The rest
/// of the file is written back byte for byte, and a file that is already up to
/// date is not written at all.
///
/// Like in 2.x, the file has to exist: it is made by `flutter create`, and
/// flavorizr does not scaffold it.
abstract class LinuxPatchProcessor extends FlavorizrProcessor {
  /// Creates a processor.
  const LinuxPatchProcessor();

  /// The file the processor patches, relative to the project.
  String get path;

  /// Returns [source], the content of [path], with its regions up to date for
  /// the flavors of [ctx].
  String patch(FlavorizrContext ctx, String source);

  @override
  Future<void> apply(FlavorizrContext ctx) async {
    final file = File(ctx.resolve(path));

    if (!file.existsSync()) {
      ctx.logger.detail('[$id] File not found at path `$path`');

      throw FileNotFoundException(path);
    }

    final (:text, :hasBom) = await BomTextFile.read(file);
    final patched = patch(ctx, text);

    if (patched != text) {
      ctx.logger.detail('[$id] Patching `$path`');

      await BomTextFile.write(file, patched, hasBom: hasBom);
    }

    ctx.track(Artifact.patched(path));
  }
}
