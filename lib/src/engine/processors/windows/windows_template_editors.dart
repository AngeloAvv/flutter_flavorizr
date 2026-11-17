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

/// The text of the Windows runner that the templates are made of, after the
/// value of each flavor was swapped for a `@VARIABLE@` that `configure_file`
/// replaces at CMake configure time (see `WindowsRunnerCMakeListsEditor`).
///
/// A template is a file flavorizr generates whole from the one of the user
/// (`main.cpp`, `Runner.rc`), which it never touches. What it changes is the
/// value of the few places that are specific of a flavor, whatever it is now:
/// the file of a project that a 2.x build ran on has the values of the flavor
/// that was built, and is templated just the same. Everything else is written
/// back byte for byte.
///
/// Like in 2.x the places are found by what they say, not parsed: one that has a
/// `//` before it on its line is in a comment and is skipped, and every other
/// one is templated, the ones of `#if` branches included. A file with none of
/// one of them is rejected with an [UnsupportedRunnerLayoutException] instead
/// of guessed at. Block comments, strings and preprocessor directives are not
/// looked at.
abstract final class _Templater {
  /// Swaps the group 2 of every match of [pattern] in a line of code for
  /// [value]: the part of the match before it, which is group 1, and the one
  /// after it, which is group 3, stay.
  ///
  /// Throws an [UnsupportedRunnerLayoutException] when there is none.
  static String replace(
    String source,
    RegExp pattern,
    String value, {
    required String path,
    required String what,
    required String fix,
  }) {
    var found = false;

    final result = source.replaceAllMapped(pattern, (match) {
      final head = source.substring(0, match.start);
      final lineStart = head.lastIndexOf('\n') + 1;

      if (head.substring(lineStart).contains('//')) return match[0]!;

      found = true;

      return '${match[1]}$value${match[3]}';
    });

    if (!found) {
      throw UnsupportedRunnerLayoutException(
        path,
        reason: 'it has no $what.',
        fix: fix,
      );
    }

    return result;
  }
}

/// The template of `windows/runner/main.cpp`: the title of the window of
/// `window.Create(L"...", origin, size)` is `@WINDOW_TITLE@`.
abstract final class WindowsMainCppTemplateEditor {
  static final RegExp _create = RegExp(
    r'(window\.Create\(L")([^"\\\r\n]*)(", origin, size\))',
  );

  /// Returns the content of `main.cpp.in` for [source], the content of
  /// `main.cpp`.
  static String template(String source) => _Templater.replace(
    source,
    _create,
    '@WINDOW_TITLE@',
    path: K.windowsMainCppPath,
    what: '`window.Create(L"...", origin, size)` call with a plain string',
    fix:
        'Restore the call as `flutter create` writes it, with a title that has '
        'no escaped characters.',
  );
}

/// The template of `windows/runner/Runner.rc`: the icon of `IDI_APP_ICON` is
/// `@RUNNER_APP_ICON@`, and the `FileDescription` and `ProductName` entries
/// are `@WINDOW_TITLE@`.
abstract final class WindowsRunnerRcTemplateEditor {
  static final RegExp _icon = RegExp(
    r'^([ \t]*IDI_APP_ICON[ \t]+ICON[ \t]+"resources\\\\)([^"\\\r\n]+)(")',
    multiLine: true,
  );

  static RegExp _entry(String name) => RegExp(
    '^([ \\t]*VALUE "$name", ")([^"\\r\\n]*)(" "\\\\0")',
    multiLine: true,
  );

  /// Returns the content of `Runner.rc.in` for [source], the content of
  /// `Runner.rc`.
  static String template(String source) {
    final withIcon = _Templater.replace(
      source,
      _icon,
      '@RUNNER_APP_ICON@',
      path: K.windowsRunnerRcPath,
      what: r'`IDI_APP_ICON ICON "resources\\<icon>"` icon',
      fix: 'Restore the icon as `flutter create` writes it.',
    );

    return ['FileDescription', 'ProductName'].fold(
      withIcon,
      (text, name) => _Templater.replace(
        text,
        _entry(name),
        '@WINDOW_TITLE@',
        path: K.windowsRunnerRcPath,
        what: '`VALUE "$name", "..." "\\0"` entry',
        fix: 'Restore the entry as `flutter create` writes it.',
      ),
    );
  }
}
