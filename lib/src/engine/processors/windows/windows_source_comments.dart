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

/// Where the comments of a C++ or resource script are.
///
/// It is not a parser: it only knows enough of the literals to tell a `//` or a
/// `/*` that starts a comment from one that is part of a string or a character,
/// such as the one of `L"https://example.com"`. It knows `"..."` and, when
/// [characterLiterals] is set, `'...'` (with their escapes, none of them going
/// past the end of its line), raw strings (`R"delimiter(...)delimiter"`),
/// line comments and block comments. The `""` that a resource script writes for
/// a quote is a string that ends and another one that starts, which is what
/// the scanner makes of it too.
abstract final class WindowsSourceComments {
  /// The comments of [source], as the offset of the first character, which is
  /// the `/` of its start, and the one after the last, which for a line comment
  /// is the line break (not part of it).
  ///
  /// A script has no character literals, and an apostrophe in it is only text:
  /// pass `characterLiterals: false`.
  static List<({int start, int end})> of(
    String source, {
    bool characterLiterals = true,
  }) {
    final comments = <({int start, int end})>[];
    var i = 0;

    while (i < source.length) {
      final c = source[i];
      final next = i + 1 < source.length ? source[i + 1] : '';

      if (c == '/' && next == '/') {
        final end = _lineEnd(source, i);

        comments.add((start: i, end: end));
        i = end;
      } else if (c == '/' && next == '*') {
        final close = source.indexOf('*/', i + 2);
        final end = close < 0 ? source.length : close + 2;

        comments.add((start: i, end: end));
        i = end;
      } else if (c == '"') {
        i = _isRawString(source, i)
            ? _rawStringEnd(source, i)
            : _quoted(source, i);
      } else if (c == "'" &&
          characterLiterals &&
          !(i > 0 && _isIdentifier(source[i - 1]))) {
        // The apostrophe of a digit separator (`1'000`) is not a literal.
        i = _quoted(source, i);
      } else {
        i++;
      }
    }

    return comments;
  }

  /// Whether [offset] is in one of the [comments] that [of] returned.
  static bool contains(List<({int start, int end})> comments, int offset) =>
      comments.any(
        (comment) => offset >= comment.start && offset < comment.end,
      );

  static int _lineEnd(String source, int from) {
    final end = source.indexOf('\n', from);

    return end < 0 ? source.length : end;
  }

  static bool _isIdentifier(String character) =>
      RegExp(r'[A-Za-z0-9_]').hasMatch(character);

  /// The offset after the literal that starts at [start], which ends at its
  /// closing quote or, when it has none, at the end of its line.
  static int _quoted(String source, int start) {
    final quote = source[start];
    var i = start + 1;

    while (i < source.length && source[i] != '\n') {
      if (source[i] == '\\') {
        i += 2;
      } else if (source[i] == quote) {
        return i + 1;
      } else {
        i++;
      }
    }

    return i < source.length ? i : source.length;
  }

  /// Whether the `"` at [quote] opens a raw string: it follows an `R`, which
  /// is not the end of a longer name, but for the prefix of a string.
  static bool _isRawString(String source, int quote) {
    if (quote == 0 || source[quote - 1] != 'R') return false;

    var before = quote - 2;

    while (before >= 0 && 'Lu8U'.contains(source[before])) {
      before--;
    }

    return before < 0 || !_isIdentifier(source[before]);
  }

  static int _rawStringEnd(String source, int quote) {
    final open = source.indexOf('(', quote);

    if (open < 0 || open - quote > 17) return _quoted(source, quote);

    final end = source.indexOf(')${source.substring(quote + 1, open)}"', open);

    return end < 0 ? source.length : end + (open - quote - 1) + 2;
  }
}
