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

import 'package:flutter_flavorizr/src/engine/processors/windows/windows_mentions.dart';
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
/// The files are not parsed. A *place* is a line written the way `flutter
/// create` writes it (see each editor), and every mention of the token it is
/// about, found by a plain search of the raw text, has to be a place: see
/// [WindowsMentions]. A file that has any other, in a comment, a string, an
/// `#if` branch that is written differently or on a line with other code, is
/// rejected with an [UnsupportedRunnerLayoutException] instead of guessed at,
/// and so is one that has none. All the places are templated.
abstract final class _Templater {
  /// Swaps the group 2 of every match of [place] in [source] for [value] (the
  /// part of the match before it is group 1 and the one after it group 3), when
  /// there are as many of them as mentions of [mention].
  static String replace(
    String source,
    RegExp mention,
    RegExp place,
    String value, {
    required String path,
    required String what,
    required String fix,
  }) {
    final places = place.allMatches(source).length;

    WindowsMentions.check(source, mention, places, path: path, what: what);

    if (places == 0) {
      throw UnsupportedRunnerLayoutException(
        path,
        reason: 'it has no $what written the way `flutter create` writes it.',
        fix: fix,
      );
    }

    return source.replaceAllMapped(
      place,
      (match) => '${match[1]}$value${match[3]}',
    );
  }
}

/// The template of `windows/runner/main.cpp`: the title of the window of
/// `window.Create(L"...", origin, size)` is `@WINDOW_TITLE@`.
///
/// A place is a line that has only that call, with a plain title (no quote and
/// no backslash, and a wide literal), after the optional `if (!` of `flutter
/// create`. The name of the window has to be `window`, with `.` or `->`.
abstract final class WindowsMainCppTemplateEditor {
  static final RegExp _mention = RegExp(r'window\s*(?:\.|->)\s*Create');
  static final RegExp _place = RegExp(
    r'^([ \t]*(?:if[ \t]*\([ \t]*!)?[ \t]*window\.Create\(L")([^"\\\r\n]*)(", origin, size\))',
    multiLine: true,
  );

  /// Returns the content of `main.cpp.in` for [source], the content of
  /// `main.cpp`.
  static String template(String source) {
    WindowsMentions.checkText(source, path: K.windowsMainCppPath);

    return _Templater.replace(
      source,
      _mention,
      _place,
      '@WINDOW_TITLE@',
      path: K.windowsMainCppPath,
      what: 'window.Create',
      fix:
          'Write the call as `flutter create` does, on a line of its own, '
          'with a title that has no escaped characters.',
    );
  }
}

/// The template of `windows/runner/Runner.rc`: the icon of `IDI_APP_ICON` is
/// `@RUNNER_APP_ICON@`, and the `FileDescription` and `ProductName` entries
/// are `@WINDOW_TITLE@`.
///
/// A place is a line `IDI_APP_ICON ICON "resources\\<icon>"`, and a line
/// `VALUE "<name>", "<title>" "\0"`.
abstract final class WindowsRunnerRcTemplateEditor {
  static final RegExp _icon = RegExp(
    r'^([ \t]*IDI_APP_ICON[ \t]+ICON[ \t]+"resources\\\\)([^"\\\r\n]+)(")',
    multiLine: true,
  );
  static final RegExp _codePage = RegExp(
    r'^[ \t]*#[ \t]*pragma[ \t]+code_page[ \t]*\([ \t]*65001[ \t]*\)[ \t]*\r?$',
    multiLine: true,
  );
  // What `flutter create` writes in the TEXTINCLUDE of the script.
  static final RegExp _textInclude = RegExp(
    r'''^[ \t]*"#include ""[^"\r\n]+\.h""\\r\\n"[ \t]*\r?$''',
    multiLine: true,
  );

  static RegExp _entry(String name) => RegExp(
    '^([ \\t]*VALUE "$name", ")([^"\\r\\n]*)(" "\\\\0")',
    multiLine: true,
  );

  /// Returns the content of `Runner.rc.in` for [source], the content of
  /// `Runner.rc`.
  ///
  /// [titles] are the titles of the windows of the flavors. The title is
  /// written in `Runner.rc` as it is, which is only right for a title that is
  /// not ASCII if the file says `#pragma code_page(65001)`, and says nothing
  /// else about the code page: it is rejected if it does not.
  static String template(String source, {Iterable<String> titles = const []}) {
    WindowsMentions.checkText(
      source,
      path: K.windowsRunnerRcPath,
      cpp: false,
      alsoRecognised: _textInclude,
    );

    if (titles.any((title) => title.runes.any((rune) => rune > 0x7f))) {
      final directives = _codePage.allMatches(source).length;

      WindowsMentions.check(
        source,
        RegExp('code_page'),
        directives,
        path: K.windowsRunnerRcPath,
        what: 'code_page',
      );

      if (directives != 1) {
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
      RegExp('IDI_APP_ICON'),
      _icon,
      '@RUNNER_APP_ICON@',
      path: K.windowsRunnerRcPath,
      what: 'IDI_APP_ICON',
      fix: r'Write it as `IDI_APP_ICON ICON "resources\\<icon>"`.',
    );

    return ['FileDescription', 'ProductName'].fold(
      withIcon,
      (text, name) => _Templater.replace(
        text,
        RegExp(name),
        _entry(name),
        '@WINDOW_TITLE@',
        path: K.windowsRunnerRcPath,
        what: name,
        fix: 'Write it as `VALUE "$name", "..." "\\0"`.',
      ),
    );
  }
}
