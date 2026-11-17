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
import 'package:flutter_flavorizr/src/engine/processors/linux/linux_cmake_lists_patch_processor.dart';
import 'package:flutter_flavorizr/src/engine/processors/linux/linux_patch_processor.dart';
import 'package:flutter_flavorizr/src/engine/processors/linux/linux_runner_cmake_lists_editor.dart';
import 'package:flutter_flavorizr/src/utils/constants.dart';

/// Forwards `FLUTTER_APP_FLAVOR` as a preprocessor define in
/// `linux/runner/CMakeLists.txt`, so that `my_application.cc` can read it with
/// `#ifdef FLUTTER_APP_FLAVOR`.
///
/// A freshly generated runner does not do it on its own. The only part of the
/// file flavorizr owns is the region that does (see
/// [LinuxRunnerCMakeListsEditor]).
///
/// It comes after `linux:cmake` when both are in the plan, which is the order of
/// 2.x. It never pulls it in: the two files are independent.
class LinuxRunnerCMakeListsPatchProcessor extends LinuxPatchProcessor {
  /// Creates the processor.
  const LinuxRunnerCMakeListsPatchProcessor();

  @override
  String get id => 'linux:runnerCmake';

  @override
  Set<String> get after => {const LinuxCMakeListsPatchProcessor().id};

  @override
  String get path => K.linuxRunnerCMakeListsPath;

  @override
  String patch(FlavorizrContext ctx, String source) =>
      LinuxRunnerCMakeListsEditor.withFlavorDefinition(source);
}
