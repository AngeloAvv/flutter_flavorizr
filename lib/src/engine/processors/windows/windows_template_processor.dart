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

/// A processor that generates a template of the Windows runner from a file of
/// the user, which it never touches.
///
/// `Runner.rc` and `main.cpp` are the ones the user owns. The template next to
/// them (`Runner.rc.in`, `main.cpp.in`) is made by flavorizr, so it is an
/// [Artifact.managed] one: it is generated whole, hashed in the lock, and a
/// hand edit of it is a conflict. The build makes the real `Runner.rc` and
/// `main.cpp` from the templates in the binary dir (see
/// `WindowsRunnerCMakeListsEditor`), so no build changes a tracked file, and the
/// user's file stays what it was and is always the one a template is made from.
///
/// The user's file is an input: it is read from the real project, and has to
/// exist, since it is made by `flutter create` and flavorizr does not scaffold
/// it. The byte order mark and the line endings are the ones of the file.
abstract class WindowsTemplateProcessor extends FlavorizrProcessor {
  /// Creates a processor.
  const WindowsTemplateProcessor();

  /// The file of the user the template is made from, relative to the project.
  String get sourcePath;

  /// The template, relative to the project.
  String get targetPath;

  /// Returns the content of the template for [source], the content of the file
  /// of the user.
  String template(String source);

  @override
  Future<void> apply(FlavorizrContext ctx) async {
    final source = File(ctx.resolveProject(sourcePath));

    if (!source.existsSync()) {
      ctx.logger.detail('[$id] File not found at path `$sourcePath`');

      throw FileNotFoundException(sourcePath);
    }

    final (:text, :hasBom) = await BomTextFile.read(source);
    final target = File(ctx.resolve(targetPath));

    ctx.logger.detail('[$id] Generating `$targetPath` from `$sourcePath`');

    await target.parent.create(recursive: true);
    await BomTextFile.write(target, template(text), hasBom: hasBom);
    ctx.track(Artifact.managed(targetPath));
  }
}
