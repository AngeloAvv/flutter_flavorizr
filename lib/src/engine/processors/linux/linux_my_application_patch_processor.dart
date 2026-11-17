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

import 'package:flutter_flavorizr/src/engine/flavorizr_context.dart';
import 'package:flutter_flavorizr/src/engine/processors/linux/linux_my_application_editor.dart';
import 'package:flutter_flavorizr/src/engine/processors/linux/linux_patch_processor.dart';
import 'package:flutter_flavorizr/src/engine/processors/linux/linux_runner_cmake_lists_patch_processor.dart';
import 'package:flutter_flavorizr/src/utils/constants.dart';

/// Sets the window title of each flavor in `linux/runner/my_application.cc`.
///
/// Every edit is inside a marked region (see [LinuxMyApplicationEditor]): unlike
/// 2.x, which rewrote the calls that set the title outside of its markers, the
/// code of the user is never touched, so a flavor that was dropped from the
/// configuration is not in the regions anymore on the next run.
///
/// The title reaches the window through `FLUTTER_APP_FLAVOR`, which
/// `linux:runnerCmake` forwards. Like in 2.x the processors are independent:
/// this one comes after it when both are in the plan, but never pulls it in, so
/// running it alone leaves the title unchanged until the other one runs.
class LinuxMyApplicationPatchProcessor extends LinuxPatchProcessor {
  /// Creates the processor.
  const LinuxMyApplicationPatchProcessor();

  @override
  String get id => 'linux:myApplication';

  @override
  Set<String> get after => {const LinuxRunnerCMakeListsPatchProcessor().id};

  @override
  String get path => K.linuxMyApplicationPath;

  @override
  String patch(FlavorizrContext ctx, String source) =>
      LinuxMyApplicationEditor.withWindowTitles(source, {
        for (final entry in ctx.config.linuxFlavors.entries)
          entry.key: entry.value.app.name,
      });
}
