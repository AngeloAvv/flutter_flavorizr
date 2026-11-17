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

import 'package:flutter_flavorizr/src/engine/processors/windows/windows_template_editors.dart';
import 'package:flutter_flavorizr/src/engine/processors/windows/windows_template_processor.dart';
import 'package:flutter_flavorizr/src/utils/constants.dart';

/// Generates `windows/runner/main.cpp.in` from `main.cpp`, with the title of the
/// window as `@WINDOW_TITLE@`, so that the build can stamp the one of the flavor
/// in the copy of `main.cpp` it makes in the binary dir. See
/// [WindowsMainCppTemplateEditor].
class WindowsMainCppTemplateProcessor extends WindowsTemplateProcessor {
  /// Creates the processor.
  const WindowsMainCppTemplateProcessor();

  @override
  String get id => 'windows:mainCppTemplate';

  @override
  String get sourcePath => K.windowsMainCppPath;

  @override
  String get targetPath => K.windowsMainCppTemplatePath;

  @override
  String template(String source) =>
      WindowsMainCppTemplateEditor.template(source);
}
