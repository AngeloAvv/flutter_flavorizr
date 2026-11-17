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

/// The guard the editors of the Windows runner rely on instead of reading the
/// language of the files.
///
/// An editor changes the places it recognises: a whole line that is written the
/// way `flutter create` writes it. It does not know what a comment, a string or
/// a directive is, so it cannot tell a place from a text that only looks like
/// it. What it can do is **count**: every mention of a token it acts on, found
/// by a plain search of the raw text (comments, strings and raw strings
/// included), has to be one of the places it recognised. If there are more
/// mentions than places the file is rejected, so a mention that is not edited
/// can never be one that matters. A file that mentions the token in a comment
/// is rejected too, which is the price of not reading the language.
abstract final class WindowsMentions {
  /// Throws an [UnsupportedRunnerLayoutException] unless [token] is mentioned
  /// in [source] exactly [recognised] times, where [recognised] is the number
  /// of places the editor found: [what] names the token in the error.
  static void check(
    String source,
    RegExp token,
    int recognised, {
    required String path,
    required String what,
  }) {
    final found = token.allMatches(source).length;

    if (found != recognised) {
      throw UnsupportedRunnerLayoutException(
        path,
        reason:
            'found $found mentions of `$what` but only $recognised in a '
            'position flavorizr understands.',
        fix:
            'Simplify the file so that each one is written the way '
            '`flutter create` writes it, or remove the extra mention (one in a '
            'comment or a string counts too).',
      );
    }
  }

  static final RegExp _continuation = RegExp(r'\\[ \t]*(?:\r?\n|\r|$)');
  static final RegExp _headerLine = RegExp(
    r'''^[ \t]*#[ \t]*include[ \t]*(?:<[^<>\r\n]+\.(?:h|hpp|hh|hxx)>|"[^"\r\n]+\.(?:h|hpp|hh|hxx)")[ \t]*\r?$''',
    multiLine: true,
  );

  /// What a file of C++ or of resources must not have, whatever is in it: a
  /// `\` that ends a line (it joins lines, so a token may be split or hidden),
  /// the digraph for `#` in C++, and an `#include` that is not of a header on a
  /// line of its own, since the file it includes may hold the tokens.
  ///
  /// [alsoRecognised] are the places of [path] that are an `#include` and are
  /// not a directive, such as the `TEXTINCLUDE` strings of a resource script.
  static void checkText(
    String source, {
    required String path,
    bool cpp = true,
    RegExp? alsoRecognised,
  }) {
    if (_continuation.hasMatch(source)) {
      throw UnsupportedRunnerLayoutException(
        path,
        reason: 'it has a line continuation (`\\` at the end of a line).',
        fix: 'Join the lines.',
      );
    }

    if (cpp && source.contains('%:')) {
      throw UnsupportedRunnerLayoutException(
        path,
        reason: 'it has a digraph (`%:`), which can write a directive.',
        fix: 'Write `#`.',
      );
    }

    check(
      source,
      RegExp(r'#[ \t]*include'),
      _headerLine.allMatches(source).length +
          (alsoRecognised?.allMatches(source).length ?? 0),
      path: path,
      what: '#include',
    );
  }
}
