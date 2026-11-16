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

/// Makes [text], which comes from a file name or a file's content, safe to
/// print on a terminal.
///
/// Control characters would be obeyed by the terminal, and could rewrite what
/// the user is shown while they decide whether to overwrite a file: the escape
/// character starts sequences, a carriage return or a backspace overwrites what
/// was printed before. They are replaced by their visible symbol (`␛`, `␍`,
/// ...), and the C1 controls, which some terminals obey too, by `�`. Newlines
/// and tabs are kept.
String printable(String text) => _visible(text, keepWhitespace: true);

/// Makes the file [path] safe to print on a terminal, on a single line.
///
/// Like [printable], but newlines and tabs are replaced too (`␊`, `␉`): a path
/// holding a newline could otherwise pass for two entries of a list.
String printablePath(String path) => _visible(path, keepWhitespace: false);

String _visible(String text, {required bool keepWhitespace}) {
  final out = StringBuffer();

  for (final unit in text.runes) {
    if (keepWhitespace && (unit == 0x0A || unit == 0x09)) {
      out.writeCharCode(unit);
    } else if (unit < 0x20) {
      out.writeCharCode(0x2400 + unit);
    } else if (unit == 0x7F) {
      out.writeCharCode(0x2421);
    } else if (unit >= 0x80 && unit <= 0x9F) {
      out.writeCharCode(0xFFFD);
    } else {
      out.writeCharCode(unit);
    }
  }

  return out.toString();
}
