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

import 'package:flutter_flavorizr/src/engine/processors/android/bom_text_file.dart';
import 'package:flutter_flavorizr/src/exception/unsupported_runner_layout_exception.dart';

/// Reads a text file of the Windows runner.
///
/// `flutter create` writes them as UTF-8, with `#pragma code_page(65001)` in
/// `Runner.rc`. The resource editor of Visual Studio may save a file as UTF-16
/// though, which cannot be edited as the text it is not, so it is rejected
/// instead of failing on the first byte, or worse, being written back as
/// something else.
abstract final class WindowsRunnerText {
  static final RegExp _control = RegExp(r'[\u0000\f\v]|\r(?!\n)');

  /// Reads [file], whose path in the project is [path]: its text, without the
  /// byte order mark, and whether it had one.
  ///
  /// Throws an [UnsupportedRunnerLayoutException] when it is not UTF-8, or has
  /// a character that no file of `flutter create` has and the editors do not
  /// model: NUL, a form feed, a vertical tab, a lone carriage return.
  /// The two kinds of line ending in one file are fine.
  static Future<({String text, bool hasBom})> read(
    File file,
    String path,
  ) async {
    try {
      final read = await BomTextFile.read(file);

      if (_control.hasMatch(read.text)) {
        throw UnsupportedRunnerLayoutException(
          path,
          reason:
              'it has a control character that is not a space or a line break '
              '(NUL, a form feed, a vertical tab or a carriage return that is '
              'not followed by a line feed).',
          fix: 'Remove it.',
        );
      }

      return read;
    } on FormatException {
      throw UnsupportedRunnerLayoutException(
        path,
        reason: 'it is not UTF-8 text (UTF-16, for one, is not supported).',
        fix: 'Save it as UTF-8, which is how `flutter create` writes it.',
      );
    }
  }
}
