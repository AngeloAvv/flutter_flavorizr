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

import 'package:flutter_flavorizr/src/engine/processors/linux/marked_text.dart';
import 'package:flutter_flavorizr/src/exception/unsafe_podfile_exception.dart';

/// The lines of a Podfile, read only to tell what is code from what is not, and
/// whether a line is inside a block.
///
/// The Podfile is Ruby and flavorizr does not parse it: it needs to find one
/// line, `project 'Runner', {`, and it must be sure that the line is code that
/// runs at the top level. So the lexer **reads a small set of constructs and
/// refuses every other one that could hide that line**, with an
/// [UnsafePodfileException]. This is the whole inventory.
///
/// **Read** (what is in them is not looked at, and a marker or the mapping line
/// in them is not code):
///
/// * comments: `#` outside a string, a `%` literal and a regular expression;
/// * strings, `'...'`, `"..."` and `` `...` `` (symbols like `:'a b'` too), that
///   close on their line, with `\` escapes, and a `#{...}` in a `"` or `` ` ``
///   string whose body has no quote, `{` or `<<`;
/// * `%q`, `%w` and `%i` literals with a bracket pair (`[]`, `()`, `{}`, `<>`),
///   nested or not, that close on their line;
/// * regular expressions `/.../` with no quote, backtick or `#` in them (but
///   for an interpolation of a name, `#{symbol}`), that close on their line;
///   division after an operand is supported, except a slash with whitespace
///   before it and none after it, which may open a command-argument regex;
/// * heredocs `<<ID`, `<<-ID` and `<<~ID`, any number on a line, whose
///   delimiter is an identifier (letters, digits, `_`, any non-ASCII character)
///   or any text in quotes (`'`, `"` or `` ` ``), even empty. The body ends on a
///   line that is the delimiter and nothing else: at the start of the line for
///   `<<ID`, after spaces or tabs for `<<-` and `<<~`;
/// * a `=begin` block, which ends on a `=end`, both at the start of a line;
/// * what follows a line that is `__END__`;
/// * a line that goes on after a backslash at its end.
///
/// **Refused**, because they cannot be told from code without parsing:
///
/// * a string, a `%` literal, a regular expression or an interpolation that
///   does not close on its line, and a heredoc that is never closed;
/// * a `#{...}` with a quote, a `{` or a heredoc in it;
/// * a `%` literal that is not `%q`, `%w` or `%i` with a bracket pair: `%Q`,
///   `%W`, `%I`, `%r`, `%s`, `%x`, `%(...)`, and any with the same character on
///   both sides (`%w|a b|`, `%q!x!`);
/// * a character literal that starts with a quote or `#` (`?'`, `?"`, `?#`) and
///   the global variables `$'`, `$"` and `` $` ``;
/// * a regular expression with a quote, a backtick or a `#` in it, other than
///   an interpolation of a name;
/// * the mapping line inside a block (`if`, `unless`, `begin`, `def`, `case`,
///   `while`, `until`, `for`, `class`, `module`, `do`, a lambda or any `{` that
///   ends a line), which [isInBlock] finds by counting each opener
///   (including assignment-form expressions), closing `end` keywords
///   (not symbols or method names), and `}`s at the start of a line.
///
/// What is **not** looked at is everything else, which is why it can be written
/// in any way: a `;` joins statements, but a mapping line has to start its
/// line, so `x = 1; project 'Runner', {` is not the mapping line.
final class LexedPodfile {
  /// The positions of the lines that are not code: heredoc bodies, `=begin`
  /// blocks, what follows `__END__`, and the lines continued with a backslash.
  final Set<int> nonCode;

  final List<TextLine> _lines;
  final Map<int, String> _code;

  const LexedPodfile._(this._lines, this.nonCode, this._code);

  // A heredoc: how it opens, the delimiter in quotes or not.
  static final RegExp _heredoc = RegExp(
    r"""(?<!\w)<<([~-]?)(?:(['"`])((?:(?!\2).)*)\2|([\w\u0080-￿]+))""",
  );
  static final RegExp _percent = RegExp(
    r'(?<![\w)\]}])%([qQwWiIrsx]?)([^\w\s=])',
  );
  static final RegExp _character = RegExp(r"""(?<![\w)\]}])\?['"`#]""");
  static final RegExp _blockStart = RegExp(r'^=begin(\s|$)');
  static final RegExp _blockEnd = RegExp(r'^=end(\s|$)');
  static final RegExp _indentation = RegExp(r'^[ \t]+');
  // An interpolation of a name, which a regular expression may have.
  static final RegExp _simple = RegExp(r'#\{[\w@.]+\}');
  static final RegExp _operand = RegExp(r'[\w)\]}]$');
  static final RegExp _opens = RegExp(
    r'(?:^|[=(,;])\s*(?:if|unless|begin|def|case|while|until|for|class|module)\b|'
    r'(?<![\w:.])do\b|\{\s*(?:\|[^|]*\|)?\s*$',
  );
  static final RegExp _end = RegExp(r'(?<![\w:.])end\b(?![!?=:])');
  static const _pairs = {'[': ']', '(': ')', '{': '}', '<': '>'};

  /// Reads [lines], the ones of the Podfile at [path].
  ///
  /// Throws an [UnsafePodfileException] for what is refused.
  static LexedPodfile read(List<TextLine> lines, String path) {
    final nonCode = <int>{};
    final code = <int, String>{};
    final pending = <({String id, bool indented})>[];
    var block = false;
    var ended = false;
    var continued = false;

    for (final line in lines) {
      final text = line.text;

      if (ended) {
        nonCode.add(line.index);
      } else if (block) {
        nonCode.add(line.index);
        block = !_blockEnd.hasMatch(text);
      } else if (pending.isNotEmpty) {
        nonCode.add(line.index);

        // Nothing may follow the delimiter, as in Ruby.
        final next = pending.first;
        final ends =
            (next.indented ? text.replaceFirst(_indentation, '') : text) ==
            next.id;

        if (ends) pending.removeAt(0);
      } else if (!continued && _blockStart.hasMatch(text)) {
        nonCode.add(line.index);
        block = true;
      } else if (!continued && text == '__END__') {
        nonCode.add(line.index);
        ended = true;
      } else {
        if (continued) nonCode.add(line.index);

        final scan = _scan(text, path);

        code[line.index] = scan.code;
        pending.addAll(scan.heredocs);
        continued = scan.continues;
      }
    }

    if (pending.isNotEmpty) {
      _refuse(
        path,
        'a heredoc (`<<${pending.first.id}`) is never closed.',
        'Close it with a line that has only `${pending.first.id}`.',
      );
    }

    return LexedPodfile._(lines, nonCode, code);
  }

  /// Whether the line at [position] is inside a block: more lines before it
  /// open one (`if`, `do`, `{`...) than there are `end`s and `}`s at the start
  /// of a line.
  bool isInBlock(int position) {
    var depth = 0;

    for (final line in _lines.take(position)) {
      final code = _code[line.index];

      if (code == null || nonCode.contains(line.index)) continue;

      final closes =
          _end.allMatches(code).length +
          (code.trimLeft().startsWith('}') ? 1 : 0);

      final opens = _opens.allMatches(code).where((match) {
        if (match.group(0) != 'do') return true;

        // A loop's optional `do` belongs to its header, not a second block.
        final statement = code.substring(
          code.lastIndexOf(';', match.start) + 1,
          match.start,
        );
        return !RegExp(r'^\s*(?:while|until|for)\b').hasMatch(statement);
      }).length;

      depth += opens - closes;
      if (depth < 0) depth = 0;
    }

    return depth > 0;
  }

  /// Reads a line: what is code in it, with a `S` for each string, literal or
  /// heredoc, the heredocs it opens, and whether it goes on in the next line.
  static ({
    String code,
    List<({String id, bool indented})> heredocs,
    bool continues,
  })
  _scan(String text, String path) {
    final code = StringBuffer();
    final heredocs = <({String id, bool indented})>[];
    String? quote;
    var comment = false;
    var i = 0;

    while (i < text.length) {
      final char = text[i];

      if (quote != null) {
        if (char == r'\') {
          i += 2;
        } else if (quote != "'" && char == '#' && text.startsWith('{', i + 1)) {
          final end = text.indexOf('}', i);

          if (end < 0 ||
              RegExp(r'''["'`{]|<<''').hasMatch(text.substring(i + 2, end))) {
            _refuse(
              path,
              'an interpolation (`#{...}`) in `${text.trim()}` has a quote, a `{` '
                  'or a heredoc in it, or is not closed on its line.',
              'Compute the value on a line of its own, and use it in the string.',
            );
          }

          i = end + 1;
        } else {
          if (char == quote) {
            quote = null;
            code.write('S');
          }

          i++;
        }

        continue;
      }

      if (char == '#') {
        comment = true;
        break;
      }

      final heredoc = char == '<' ? _heredoc.matchAsPrefix(text, i) : null;
      final quoted = heredoc?[2] != null;
      final id = heredoc == null ? '' : (quoted ? heredoc[3]! : heredoc[4]!);
      final indented = heredoc?[1]?.isNotEmpty ?? false;

      // `<<1` is a shift, but `<<~1` is a heredoc.
      if (heredoc != null &&
          (quoted || indented || !RegExp(r'^\d').hasMatch(id))) {
        heredocs.add((id: id, indented: indented));
        code.write('S');
        i = heredoc.end;
        continue;
      }

      final percent = char == '%' ? _percent.matchAsPrefix(text, i) : null;

      if (percent != null) {
        final kind = percent[1]!;
        final open = percent[2]!;
        final reads =
            kind.isNotEmpty && 'qwi'.contains(kind) && _pairs.containsKey(open);
        final end = reads ? _closing(text, percent.end, open) : null;

        if (end == null) {
          _refuse(
            path,
            reads
                ? 'a `%` literal that goes over several lines starts on '
                      '`${text.trim()}`.'
                : 'the `%` literal `${percent[0]}` in `${text.trim()}` is not one '
                      'flavorizr reads: it reads `%q`, `%w` and `%i` with a bracket '
                      'pair.',
            'Write it as a string or an array on one line.',
          );
        }

        code.write('S');
        i = end;
        continue;
      }

      if (_character.matchAsPrefix(text, i) != null) {
        _refuse(
          path,
          'the character literal `${text.substring(i, i + 2)}` in `${text.trim()}`'
              ' cannot be told from a string.',
          'Write it as a string: `"x"`.',
        );
      }

      if (char == r'$' && i + 1 < text.length && '\'"`'.contains(text[i + 1])) {
        _refuse(
          path,
          'the global variable `${text.substring(i, i + 2)}` in `${text.trim()}` '
              'cannot be told from a string.',
          'Use another way to read it, such as `Regexp.last_match`.',
        );
      }

      if (char == '/' &&
          _operand.hasMatch(code.toString().trimRight()) &&
          i > 0 &&
          text[i - 1].trim().isEmpty &&
          i + 1 < text.length &&
          text[i + 1].trim().isNotEmpty) {
        _refuse(
          path,
          'a slash in `${text.trim()}` may start a command-argument regular expression.',
          'Use `Regexp.new(...)` for the regular expression, or put spaces on both sides of a division.',
        );
      }

      if (char == '/' && !_operand.hasMatch(code.toString().trimRight())) {
        final end = _closing(text, i + 1, '/');

        if (end == null ||
            RegExp(
              r'''["'`#]''',
            ).hasMatch(text.substring(i, end).replaceAll(_simple, ''))) {
          _refuse(
            path,
            'the regular expression in `${text.trim()}` has a quote, a backtick or '
                'a `#` in it, or goes over several lines.',
            'Write it with `Regexp.new("...")` on one line, or move it out of the '
                'Podfile.',
          );
        }

        code.write('S');
        i = end;
        continue;
      }

      if (char == "'" || char == '"' || char == '`') {
        quote = char;
      } else {
        code.write(char);
      }

      i++;
    }

    if (quote != null) {
      _refuse(
        path,
        'a string that goes over several lines starts on `${text.trim()}`.',
        'Write it on one line, or as a heredoc.',
      );
    }

    return (
      code: code.toString(),
      heredocs: heredocs,
      continues: !comment && text.endsWith(r'\'),
    );
  }

  /// Where the literal that opens with [open] ends in [text], read from [from],
  /// or `null` when it does not close on this line. A literal that has the same
  /// character on both sides (`/`) does not nest.
  static int? _closing(String text, int from, String open) {
    final close = _pairs[open] ?? open;
    var depth = 1;
    var i = from;

    while (i < text.length) {
      final char = text[i];

      if (char == r'\') {
        i += 2;
        continue;
      }

      if (char == open && close != open) depth++;
      if (char == close && --depth == 0) return i + 1;

      i++;
    }

    return null;
  }

  static Never _refuse(String path, String reason, String fix) =>
      throw UnsafePodfileException(path, reason: reason, fix: fix);
}
