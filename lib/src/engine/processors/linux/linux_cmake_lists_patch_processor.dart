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
import 'package:flutter_flavorizr/src/engine/processors/linux/linux_cmake_lists_editor.dart';
import 'package:flutter_flavorizr/src/engine/processors/linux/linux_patch_processor.dart';
import 'package:flutter_flavorizr/src/utils/constants.dart';

/// Sets the application id of each flavor in `linux/CMakeLists.txt`.
///
/// The only part of the file flavorizr owns is the region that overrides
/// `APPLICATION_ID` (see [LinuxCMakeListsEditor]). A flavor that was dropped
/// from the configuration is not in the region anymore on the next run.
class LinuxCMakeListsPatchProcessor extends LinuxPatchProcessor {
  /// Creates the processor.
  const LinuxCMakeListsPatchProcessor();

  @override
  String get id => 'linux:cmake';

  @override
  String get path => K.linuxCMakeListsPath;

  @override
  String patch(FlavorizrContext ctx, String source) =>
      LinuxCMakeListsEditor.withApplicationIds(source, {
        for (final entry in ctx.config.linuxFlavors.entries)
          entry.key: entry.value.linux!.applicationId,
      });
}
