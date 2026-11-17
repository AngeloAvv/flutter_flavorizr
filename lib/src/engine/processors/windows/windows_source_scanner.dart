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

/// What [WindowsSourceScanner.scan] found in a text.
final class WindowsSourceScan {
  /// The comments, as the offset of the first character, which is the `/` of
  /// its start, and the one after the last, which for a line comment is the
  /// line break (not part of it).
  final List<({int start, int end})> comments;

  const WindowsSourceScan._(this.comments);

  /// Whether [offset] is in a comment.
  bool inComment(int offset) => comments.any(
    (comment) => offset >= comment.start && offset < comment.end,
  );
}

/// Finds the comments of the C++ or resource script of the Windows runner, and
/// rejects the text it would have to guess at.
///
/// It is not a parser, and it is meant to stay small: what it does not model it
/// **rejects**, with an [UnsupportedRunnerLayoutException], instead of
/// mis-reading it. The inventory:
///
/// * Supported: `//` and `/* */` comments (which do not nest, and neither
///   starts inside the other or inside a literal), `//` comments that go on with
///   a `\` at the end of the line, `"..."` strings with their escapes, raw
///   strings (`R"delimiter(...)delimiter"`, with the prefixes `L`, `u`, `U` and
///   `u8`), `'...'` characters with the same prefixes (C++ only), the digit
///   separator `1'000`, CRLF, LF or both in one file. The `""` of a script is a
///   string that ends and another one that starts, which is what it is read as.
/// * Rejected: a string, character, raw string or block comment that is not
///   closed (a string or a character ends with its line); a raw string whose
///   delimiter is not up to 16 characters without spaces, `(`, `)` or `\`; a
///   `\` that ends a line anywhere but in a `//` comment (a continued string,
///   macro or directive); digraphs, in C++ (`<%`, `%>`, `<:`, `:>`, `%:`); an
///   `#include` that is not of a header (`.h`, `.hpp`, `.hh`, `.hxx`) named by
///   a literal, since the file may be generated and hold what is looked for.
/// * Not supported, because the compiler does not either: trigraphs (`??/`).
///   MSVC reads them only with `/Zc:trigraphs`, which Flutter does not ask for,
///   so `??/` at the end of a line is no continuation here.
///
/// Whatever is not a comment (preprocessor directives, macros, `#if` branches)
/// is code for the scanner, which does not tell which branch is built.
abstract final class WindowsSourceScanner {
  static final RegExp _include = RegExp(
    r'^[ \t]*#[ \t]*include\b([^\r\n]*)',
    multiLine: true,
  );
  static final RegExp _header = RegExp(
    r'''^[ \t]*(?:<[^<>\r\n]*\.(?:h|hpp|hh|hxx)>|"[^"\r\n]*\.(?:h|hpp|hh|hxx)")''',
  );
  static final RegExp _digraph = RegExp(r'<:(?!:)|:>|<%|%>|%:');

  /// Scans [source], the content of the file [path] of the project.
  ///
  /// A script has no characters (`'`) and no digraphs: pass `cpp: false`.
  ///
  /// Throws an [UnsupportedRunnerLayoutException] on what is rejected.
  static WindowsSourceScan scan(
    String source, {
    required String path,
    bool cpp = true,
  }) {
    final comments = <({int start, int end})>[];
    final literals = <({int start, int end})>[];
    var i = 0;

    Never reject(String what, String fix) =>
        throw UnsupportedRunnerLayoutException(
          path,
          reason: 'it has $what.',
          fix: fix,
        );

    while (i < source.length) {
      final c = source[i];
      final next = i + 1 < source.length ? source[i + 1] : '';

      if (c == '/' && next == '/') {
        final end = _commentEnd(source, i);

        comments.add((start: i, end: end));
        i = end;
      } else if (c == '/' && next == '*') {
        final close = source.indexOf('*/', i + 2);

        if (close < 0) {
          reject(
            'a block comment that is not closed',
            'Close the comment with `*/`.',
          );
        }

        comments.add((start: i, end: close + 2));
        i = close + 2;
      } else if (c == '\\' && _isLineEnd(source, i + 1)) {
        reject(
          'a line continuation (`\\` at the end of a line) outside of a `//` '
              'comment',
          'Join the lines.',
        );
      } else if (c == '"' && _isRaw(source, i)) {
        final end = _rawEnd(source, i, reject);

        literals.add((start: i, end: end));
        i = end;
      } else if (c == '"' || (c == "'" && cpp && _isCharacter(source, i))) {
        final end = _quotedEnd(source, i, reject);

        literals.add((start: i, end: end));
        i = end;
      } else {
        i++;
      }
    }

    final scan = WindowsSourceScan._(comments);
    final skipped = [...comments, ...literals];
    bool skips(int offset) =>
        skipped.any((range) => offset >= range.start && offset < range.end);

    for (final match in _include.allMatches(source)) {
      final directive = match.start + match[0]!.indexOf('#');

      if (!skips(directive) && !_header.hasMatch(match[1]!)) {
        reject(
          'an `#include` that is not of a header (`.h`, `.hpp`) named by a '
              'literal: `${match[0]!.trim()}`',
          'Include headers only: the file of an `#include` that is not one may '
              'hold the code that is looked for.',
        );
      }
    }

    if (cpp) {
      final masked = StringBuffer();

      for (var offset = 0; offset < source.length; offset++) {
        masked.write(
          skips(offset) && source[offset] != '\n' ? ' ' : source[offset],
        );
      }

      final digraph = _digraph.firstMatch(masked.toString());

      if (digraph != null) {
        reject(
          'a digraph (`${digraph[0]}`)',
          'Write the character it stands for.',
        );
      }
    }

    return scan;
  }

  static bool _isLineEnd(String source, int offset) =>
      offset < source.length &&
      (source[offset] == '\n' ||
          (source[offset] == '\r' &&
              offset + 1 < source.length &&
              source[offset + 1] == '\n'));

  /// The offset of the line break that ends the `//` comment at [start]: a `\`
  /// right before it goes on with the next line.
  static int _commentEnd(String source, int start) {
    var end = source.indexOf('\n', start);

    while (end > 0 && end < source.length) {
      final before = source[end - 1] == '\r' ? end - 2 : end - 1;

      if (before < 0 || source[before] != '\\') break;

      final following = source.indexOf('\n', end + 1);

      if (following < 0) return source.length;

      end = following;
    }

    return end < 0 ? source.length : end;
  }

  static bool _isIdentifier(String character) =>
      RegExp(r'[A-Za-z0-9_]').hasMatch(character);

  /// Whether the `'` at [quote] starts a character, and not the digit
  /// separator of `1'000`: it does after the prefix of a character (`L`, `u`,
  /// `U`, `u8`) that is not the end of a longer name, and after anything that
  /// is not a name.
  static bool _isCharacter(String source, int quote) {
    if (quote == 0 || !_isIdentifier(source[quote - 1])) return true;

    final prefix = RegExp(
      r'(?:u8|[LuU])$',
    ).firstMatch(source.substring(quote >= 2 ? quote - 2 : 0, quote));

    if (prefix == null) return false;

    final before = quote - prefix[0]!.length - 1;

    return before < 0 || !_isIdentifier(source[before]);
  }

  /// The offset after the string or character that starts at [start], which is
  /// closed on its line.
  static int _quotedEnd(
    String source,
    int start,
    Never Function(String, String) reject,
  ) {
    final quote = source[start];
    var i = start + 1;

    while (i < source.length && source[i] != '\n' && source[i] != '\r') {
      if (source[i] == '\\') {
        if (_isLineEnd(source, i + 1)) {
          reject(
            'a line continuation (`\\` at the end of a line) in a string or '
                'a character',
            'Join the lines.',
          );
        }

        i += 2;
      } else if (source[i] == quote) {
        return i + 1;
      } else {
        i++;
      }
    }

    return reject(
      'a ${quote == '"' ? 'string' : 'character'} that is not closed on its '
          'line',
      'Close it with `$quote`.',
    );
  }

  /// Whether the `"` at [quote] opens a raw string: it follows an `R`, which is
  /// not the end of a longer name, but for the prefix of a string.
  static bool _isRaw(String source, int quote) {
    if (quote == 0 || source[quote - 1] != 'R') return false;

    var before = quote - 2;

    while (before >= 0 && 'Lu8U'.contains(source[before])) {
      before--;
    }

    return before < 0 || !_isIdentifier(source[before]);
  }

  static int _rawEnd(
    String source,
    int quote,
    Never Function(String, String) reject,
  ) {
    final open = source.indexOf('(', quote);
    final delimiter = open < 0 ? '' : source.substring(quote + 1, open);

    if (open < 0 ||
        delimiter.length > 16 ||
        RegExp(r'[\s)\\"]').hasMatch(delimiter)) {
      reject(
        'a raw string whose delimiter is not up to 16 characters without '
            'spaces, parentheses or `\\`',
        'Use a shorter delimiter.',
      );
    }

    final end = source.indexOf(')$delimiter"', open);

    if (end < 0) {
      reject(
        'a raw string that is not closed',
        'Close it with `)$delimiter"`.',
      );
    }

    return end + delimiter.length + 2;
  }
}
