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

/// Templates the icon reference and window title strings in `Runner.rc` into
/// `@RUNNER_APP_ICON@`/`@WINDOW_TITLE@`, so `configure_file()` can stamp them
/// back in per-flavor at CMake configure time.
class WindowsRunnerRcContentProcessor extends StringProcessor {
  static const _iconAnchor = r'"resources\\app_icon.ico"';
  static const _iconReplacement = '"resources\\\\@RUNNER_APP_ICON@"';

  static final RegExp _fileDescriptionLiteral = RegExp(
    r'(VALUE "FileDescription", ")[^"]*(" "\\0")',
  );
  static final RegExp _productNameLiteral = RegExp(
    r'(VALUE "ProductName", ")[^"]*(" "\\0")',
  );

  WindowsRunnerRcContentProcessor({
    super.input,
    required super.config,
    required super.logger,
  });

  @override
  String execute() {
    logger.detail(
      '[$WindowsRunnerRcContentProcessor] Templating icon and window title in Runner.rc.in',
    );

    final alreadyTemplated = input!.contains('@RUNNER_APP_ICON@');

    if (!input!.contains(_iconAnchor) && !alreadyTemplated) {
      logger.detail(
        '[$WindowsRunnerRcContentProcessor] No `$_iconAnchor` found in Runner.rc',
        style: logger.theme.err,
      );

      throw MalformedResourceException(input!);
    }

    if (!_fileDescriptionLiteral.hasMatch(input!) ||
        !_productNameLiteral.hasMatch(input!)) {
      logger.detail(
        '[$WindowsRunnerRcContentProcessor] No FileDescription/ProductName VERSIONINFO entries found in Runner.rc',
        style: logger.theme.err,
      );

      throw MalformedResourceException(input!);
    }

    var output = alreadyTemplated
        ? input!
        : input!.replaceFirst(_iconAnchor, _iconReplacement);
    output = output.replaceFirstMapped(
      _fileDescriptionLiteral,
      (match) => '${match.group(1)}@WINDOW_TITLE@${match.group(2)}',
    );
    output = output.replaceFirstMapped(
      _productNameLiteral,
      (match) => '${match.group(1)}@WINDOW_TITLE@${match.group(2)}',
    );

    logger.detail(
      '[$WindowsRunnerRcContentProcessor] Runner.rc.in templated',
      style: logger.theme.success,
    );

    return output;
  }

  @override
  String toString() => 'WindowsRunnerRcContentProcessor';
}
