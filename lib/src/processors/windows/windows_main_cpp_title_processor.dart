/*
 * Copyright (c) 2024 Angelo Cassano
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

import 'package:flutter_flavorizr/src/exception/malformed_resource_exception.dart';
import 'package:flutter_flavorizr/src/processors/commons/string_processor.dart';

/// Templates the literal window title in `main.cpp` into `@WINDOW_TITLE@`, so
/// `configure_file()` can stamp it back in per-flavor at CMake configure time.
class WindowsMainCppTitleProcessor extends StringProcessor {
  static final RegExp _windowCreateLiteral = RegExp(
    r'(window\.Create\(L")[^"]*(", origin, size\))',
  );

  WindowsMainCppTitleProcessor({
    super.input,
    required super.config,
    required super.logger,
  });

  @override
  String execute() {
    logger.detail(
      '[$WindowsMainCppTitleProcessor] Templating window title in main.cpp.in',
    );

    if (!_windowCreateLiteral.hasMatch(input!)) {
      logger.detail(
        '[$WindowsMainCppTitleProcessor] No `window.Create(L"...", origin, size)` call found in main.cpp',
        style: logger.theme.err,
      );

      throw MalformedResourceException(input!);
    }

    final output = input!.replaceFirstMapped(
      _windowCreateLiteral,
      (match) => '${match.group(1)}@WINDOW_TITLE@${match.group(2)}',
    );

    logger.detail(
      '[$WindowsMainCppTitleProcessor] main.cpp.in templated',
      style: logger.theme.success,
    );

    return output;
  }

  @override
  String toString() => 'WindowsMainCppTitleProcessor';
}
