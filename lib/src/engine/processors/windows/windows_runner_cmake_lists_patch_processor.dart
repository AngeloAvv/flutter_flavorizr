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
import 'package:flutter_flavorizr/src/engine/processors/darwin/xcconfig_naming.dart';
import 'package:flutter_flavorizr/src/engine/processors/windows/windows_icons_processor.dart';
import 'package:flutter_flavorizr/src/engine/processors/windows/windows_runner_cmake_lists_editor.dart';
import 'package:flutter_flavorizr/src/engine/processors/windows/windows_runner_text.dart';
import 'package:flutter_flavorizr/src/engine/processors/windows/windows_runner_rc_template_processor.dart';
import 'package:flutter_flavorizr/src/exception/file_not_found_exception.dart';
import 'package:flutter_flavorizr/src/utils/constants.dart';

/// Wires `FLUTTER_APP_FLAVOR` to a per-flavor icon and window title in
/// `windows/runner/CMakeLists.txt`, and builds `Runner.rc` and `main.cpp` from
/// their templates in the binary dir.
///
/// The file belongs to the user: it is an [Artifact.patched] artifact and the
/// only part flavorizr owns is its marked region (see
/// [WindowsRunnerCMakeListsEditor]). The rest of the file is written back byte
/// for byte, and a file that is already up to date is not written at all.
///
/// A flavor is pointed at its `<flavor>.ico` when `windows:icons` makes one for
/// it (see [windowsMakesIcon]: the same condition that processor decides by), or
/// when the project has one that the lock does not know, which is the user's.
/// One that the lock recorded is `windows:icons`'s own, and goes when the flavor
/// makes none: the flavor builds with `app_icon.ico` instead.
///
/// Like in 2.x, the file has to exist: it is made by `flutter create`, and
/// flavorizr does not scaffold it.
///
/// It comes after the processors that make the templates when they are in the
/// plan, which is the order of 2.x. It never pulls them in.
class WindowsRunnerCMakeListsPatchProcessor extends FlavorizrProcessor {
  /// Creates the processor.
  const WindowsRunnerCMakeListsPatchProcessor();

  @override
  String get id => 'windows:cmake';

  @override
  Set<String> get after => {const WindowsRunnerRcTemplateProcessor().id};

  @override
  Future<void> apply(FlavorizrContext ctx) async {
    final path = K.windowsRunnerCMakeListsPath;
    final file = File(ctx.resolve(path));

    if (!file.existsSync()) {
      ctx.logger.detail('[$id] File not found at path `$path`');

      throw FileNotFoundException(path);
    }

    final (:text, :hasBom) = await WindowsRunnerText.read(file, path);
    final patched = WindowsRunnerCMakeListsEditor.withFlavors(
      text,
      {
        for (final MapEntry(key: name, value: flavor)
            in ctx.config.windowsFlavors.entries)
          name: flavor.app.name,
      },
      // A flavor has an icon of its own when `windows:icons` makes one for it
      // (it asks for one, or has a badge), or when the project has it and it is
      // the user's. An `.ico` that the lock recorded is not: it is the one
      // `windows:icons` made, and removes when the flavor makes none, so the
      // flavor is not pointed at it. Any other flavor builds with the
      // `app_icon.ico` of the project.
      icons: {
        for (final MapEntry(key: name, value: flavor)
            in ctx.config.windowsFlavors.entries)
          if (windowsMakesIcon(ctx, name, flavor) || _isUsers(ctx, name)) name,
      },
    );

    if (patched != text) {
      ctx.logger.detail('[$id] Patching `$path`');

      await BomTextFile.write(file, patched, hasBom: hasBom);
    }

    ctx.track(Artifact.patched(path));
  }

  /// Whether the project has an `.ico` for [flavor] that is the user's: the lock
  /// does not know it.
  static bool _isUsers(FlavorizrContext ctx, String flavor) {
    final path = windowsIcoPath(flavor);

    // A name that is not one of a file is not looked for: it would lead
    // somewhere else in the project.
    return isValidFlavorName(flavor) &&
        File(ctx.resolveProject(path)).existsSync() &&
        !ctx.hasPreviousFile(path);
  }
}
