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

import 'package:flutter_flavorizr/src/exception/unsupported_runner_layout_exception.dart';
import 'package:flutter_flavorizr/src/utils/constants.dart';

/// How the title of a window is written for each place it ends up in.
///
/// The name of the app of a flavor travels a long way: it is the value of a
/// CMake variable, which `configure_file` then puts, as it is, in the middle of
/// a string literal of `main.cpp` (`L"..."`) and in two of `Runner.rc`
/// (`VALUE "FileDescription", "..."`). It has to be encoded for the language of
/// the literal it ends up in first, since nothing does it after, and then for
/// the CMake argument that holds it, which CMake decodes:
///
/// ```text
/// title -> [cpp | rc] -> cmake -> set(WINDOW_TITLE_CPP "...") -> main.cpp
/// ```
///
/// A title with nothing special in it is written as it is in all of them.
abstract final class WindowsTitleEncoding {
  /// The flavor names that can be used: they are the name of an icon file and
  /// the right side of a comparison in CMake, and go in a path of `Runner.rc`.
  static final RegExp _plainName = RegExp(r'^[A-Za-z0-9_.-]+$');

  /// Throws an [UnsupportedRunnerLayoutException] when the [flavor] or its
  /// [title] cannot be used.
  static void check(String flavor, String title) {
    if (!_plainName.hasMatch(flavor)) {
      throw UnsupportedRunnerLayoutException(
        K.windowsRunnerCMakeListsPath,
        reason:
            'the name of the flavor `$flavor` has characters other than '
            'letters, digits, `_`, `-` and `.`, and it is the name of the '
            'icon file of the flavor, written in CMake and in `Runner.rc`.',
        fix: 'Rename the flavor.',
      );
    }

    if (title.runes.any(_isControl)) {
      throw UnsupportedRunnerLayoutException(
        K.windowsRunnerCMakeListsPath,
        reason:
            'the name of the app of the flavor `$flavor` has a control '
            'character (a line break or a tab, for one), which cannot be in '
            'the title of a window.',
        fix: 'Remove it from `app.name` of the flavor.',
      );
    }
  }

  static bool _isControl(int rune) =>
      rune < 0x20 || (rune >= 0x7f && rune <= 0x9f);

  /// [title] as the inside of the wide string literal of `main.cpp`: `\` and
  /// `"` escaped, and what is not ASCII as a universal character name, so that
  /// it does not depend on how the compiler reads the file, which Flutter does
  /// not ask to be UTF-8.
  static String cpp(String title) => title.runes.map((rune) {
    return switch (rune) {
      0x5c => r'\\',
      0x22 => r'\"',
      < 0x80 => String.fromCharCode(rune),
      <= 0xffff => '\\u${rune.toRadixString(16).padLeft(4, '0')}',
      _ => '\\U${rune.toRadixString(16).padLeft(8, '0')}',
    };
  }).join();

  /// [title] as the inside of a string of `Runner.rc`: a quote is written twice
  /// and `\` is escaped. The file says `#pragma code_page(65001)`, so what is
  /// not ASCII stays as it is.
  static String rc(String title) =>
      title.replaceAll(r'\', r'\\').replaceAll('"', '""');

  /// [value] as the inside of a quoted argument of CMake: `\`, `"` and the `$`
  /// that would start a reference are escaped.
  static String cmake(String value) => value
      .replaceAll(r'\', r'\\')
      .replaceAll('"', r'\"')
      .replaceAll(r'$', r'\$');
}
