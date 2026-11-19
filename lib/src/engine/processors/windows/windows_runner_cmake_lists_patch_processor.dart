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
import 'package:flutter_flavorizr/src/engine/processors/windows/windows_runner_cmake_lists_editor.dart';
import 'package:flutter_flavorizr/src/engine/processors/windows/windows_runner_text.dart';
import 'package:flutter_flavorizr/src/engine/processors/windows/windows_runner_rc_template_processor.dart';
import 'package:flutter_flavorizr/src/exception/file_not_found_exception.dart';
import 'package:flutter_flavorizr/src/utils/constants.dart';
import 'package:path/path.dart' as p;

/// Wires `FLUTTER_APP_FLAVOR` to a per-flavor icon and window title in
/// `windows/runner/CMakeLists.txt`, and builds `Runner.rc` and `main.cpp` from
/// their templates in the binary dir.
///
/// The file belongs to the user: it is an [Artifact.patched] artifact and the
/// only part flavorizr owns is its marked region (see
/// [WindowsRunnerCMakeListsEditor]). The rest of the file is written back byte
/// for byte, and a file that is already up to date is not written at all.
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
      // A flavor has an icon of its own when it asks for one, has a badge (the
      // icon is made for it), or when the project already has it: it is the
      // user's. Any other flavor builds with the `app_icon.ico` of the
      // project.
      icons: {
        for (final MapEntry(key: name, value: flavor)
            in ctx.config.windowsFlavors.entries)
          if (flavor.app.icon != null ||
              flavor.windows?.icon != null ||
              ctx.config.badgeOf(name) != null ||
              File(
                p.join(
                  ctx.projectRoot.path,
                  K.windowsIconsPath,
                  '$name.ico',
                ),
              ).existsSync())
            name,
      },
    );

    if (patched != text) {
      ctx.logger.detail('[$id] Patching `$path`');

      await BomTextFile.write(file, patched, hasBom: hasBom);
    }

    ctx.track(Artifact.patched(path));
  }
}
