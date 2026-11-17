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
import 'package:flutter_flavorizr/src/engine/processors/windows/windows_main_cpp_template_processor.dart';
import 'package:flutter_flavorizr/src/engine/processors/windows/windows_template_editors.dart';
import 'package:flutter_flavorizr/src/engine/processors/windows/windows_template_processor.dart';
import 'package:flutter_flavorizr/src/utils/constants.dart';

/// Generates `windows/runner/Runner.rc.in` from `Runner.rc`, with the icon and
/// the title of the window as `@RUNNER_APP_ICON@` and `@WINDOW_TITLE@`, so that
/// the build can stamp the ones of the flavor in the copy of `Runner.rc` it
/// makes in the binary dir. See [WindowsRunnerRcTemplateEditor].
///
/// It comes after `windows:mainCppTemplate` when both are in the plan, which is
/// the order of 2.x. It never pulls it in: the two files are independent.
class WindowsRunnerRcTemplateProcessor extends WindowsTemplateProcessor {
  /// Creates the processor.
  const WindowsRunnerRcTemplateProcessor();

  @override
  String get id => 'windows:runnerRcTemplate';

  @override
  Set<String> get after => {const WindowsMainCppTemplateProcessor().id};

  @override
  String get sourcePath => K.windowsRunnerRcPath;

  @override
  String get targetPath => K.windowsRunnerRcTemplatePath;

  @override
  String template(FlavorizrContext ctx, String source) =>
      WindowsRunnerRcTemplateEditor.template(
        source,
        titles: [
          for (final flavor in ctx.config.windowsFlavors.values)
            flavor.app.name,
        ],
      );
}
