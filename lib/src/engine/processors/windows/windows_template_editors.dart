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

import 'package:flutter_flavorizr/src/engine/processors/windows/windows_source_scanner.dart';
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
/// Like in 2.x the places are found by what they say, not parsed: one that is in a
/// comment (`//` or `/* */`, which the literals do not start) is skipped, and every other
/// one is templated, the ones of `#if` branches included. **All** of them have
/// to be written the way `flutter create` writes them, since a build may pick
/// any: a file with one that is not (a raw or `u8` string, a macro, two
/// literals, an escaped quote), or with none of one of them, is rejected with
/// an [UnsupportedRunnerLayoutException] instead of guessed at. Block comments,
/// strings and preprocessor directives are not looked at, so a `window.Create(`
/// in a string is one that cannot be templated.
abstract final class _Templater {
  /// Swaps the group 2 of every match of [supported] in a line of code for
  /// [value]: the part of the match before it, which is group 1, and the one
  /// after it, which is group 3, stay.
  ///
  /// [candidate] finds every place that is [what], however it is written, and
  /// [supported] (which has to start where it does) the ones that can be
  /// templated. All of them have to be: a place that is not would keep the
  /// title of the file for a build that picks it, so it is a rejection and the
  /// others are not templated either. A place that is in a comment (see
  /// [WindowsSourceScanner]) is skipped.
  ///
  /// Throws an [UnsupportedRunnerLayoutException] when a place cannot be
  /// templated, and when there is none.
  static String replace(
    String source,
    RegExp candidate,
    RegExp supported,
    String value, {
    required String path,
    required String what,
    required String fix,
    bool characterLiterals = true,
  }) {
    final scan = WindowsSourceScanner.scan(
      source,
      path: path,
      cpp: characterLiterals,
    );
    final inComment = scan.inComment;

    final templatable = {
      for (final match in supported.allMatches(source)) match.start,
    };
    var found = false;

    for (final match in candidate.allMatches(source)) {
      if (inComment(match.start)) continue;

      if (!templatable.contains(match.start)) {
        final line = source
            .substring(match.start)
            .split(RegExp(r'\r?\n'))
            .first;

        throw UnsupportedRunnerLayoutException(
          path,
          reason: 'it has `${line.trim()}`, which is not a $what.',
          fix: fix,
        );
      }

      found = true;
    }

    if (!found) {
      throw UnsupportedRunnerLayoutException(
        path,
        reason: 'it has no $what.',
        fix: fix,
      );
    }

    return source.replaceAllMapped(
      supported,
      (match) =>
          inComment(match.start) ? match[0]! : '${match[1]}$value${match[3]}',
    );
  }
}

/// The template of `windows/runner/main.cpp`: the title of the window of
/// `window.Create(L"...", origin, size)` is `@WINDOW_TITLE@`.
abstract final class WindowsMainCppTemplateEditor {
  static final RegExp _call = RegExp(r'\bwindow\s*(?:\.|->)\s*Create\b');
  static final RegExp _create = RegExp(
    r'(window\.Create\(L")([^"\\\r\n]*)(", origin, size\))',
  );

  /// Returns the content of `main.cpp.in` for [source], the content of
  /// `main.cpp`.
  static String template(String source) => _Templater.replace(
    source,
    _call,
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
  static final RegExp _iconCandidate = RegExp(
    r'^[ \t]*IDI_APP_ICON\b',
    multiLine: true,
  );
  static final RegExp _icon = RegExp(
    r'^([ \t]*IDI_APP_ICON[ \t]+ICON[ \t]+"resources\\\\)([^"\\\r\n]+)(")',
    multiLine: true,
  );

  static RegExp _entryCandidate(String name) =>
      RegExp('^[ \\t]*VALUE[ \\t]+"$name"', multiLine: true);

  static RegExp _entry(String name) => RegExp(
    '^([ \\t]*VALUE "$name", ")([^"\\r\\n]*)(" "\\\\0")',
    multiLine: true,
  );

  static final RegExp _codePage = RegExp(
    r'^[ \t]*#[ \t]*pragma[ \t]+code_page[ \t]*\([ \t]*65001[ \t]*\)',
    multiLine: true,
  );

  /// Returns the content of `Runner.rc.in` for [source], the content of
  /// `Runner.rc`.
  ///
  /// [titles] are the titles of the windows of the flavors. The title is
  /// written in `Runner.rc` as it is, which is only right for a title that is
  /// not ASCII if the file says `#pragma code_page(65001)`: it is rejected if
  /// it does not, since the resource compiler would read the bytes of the title
  /// in the code page of the machine. The file of `flutter create` has it.
  static String template(String source, {Iterable<String> titles = const []}) {
    if (titles.any((title) => title.runes.any((rune) => rune > 0x7f))) {
      final scan = WindowsSourceScanner.scan(
        source,
        path: K.windowsRunnerRcPath,
        cpp: false,
      );

      if (!_codePage.allMatches(source).any((m) => !scan.inComment(m.start))) {
        throw UnsupportedRunnerLayoutException(
          K.windowsRunnerRcPath,
          reason:
              'a title is not ASCII and the file has no `#pragma '
              'code_page(65001)` that makes it UTF-8.',
          fix:
              'Add `#pragma code_page(65001)` at the top of the file, as '
              '`flutter create` writes it, or use an ASCII `app.name`.',
        );
      }
    }

    final withIcon = _Templater.replace(
      source,
      _iconCandidate,
      _icon,
      '@RUNNER_APP_ICON@',
      path: K.windowsRunnerRcPath,
      characterLiterals: false,
      what: r'`IDI_APP_ICON ICON "resources\\<icon>"` icon',
      fix: 'Restore the icon as `flutter create` writes it.',
    );

    return ['FileDescription', 'ProductName'].fold(
      withIcon,
      (text, name) => _Templater.replace(
        text,
        _entryCandidate(name),
        _entry(name),
        '@WINDOW_TITLE@',
        path: K.windowsRunnerRcPath,
        characterLiterals: false,
        what: '`VALUE "$name", "..." "\\0"` entry',
        fix: 'Restore the entry as `flutter create` writes it.',
      ),
    );
  }
}
