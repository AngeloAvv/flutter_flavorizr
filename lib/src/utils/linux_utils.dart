/*
 * Copyright (c) 2024 Angelo Cassano
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

/// Strips a previously injected `beginMarkup`/`endMarkup` block, so
/// re-running a processor doesn't duplicate it. Only removes the block's own
/// lines (never the newline that terminates whatever precedes it), then
/// collapses any run of blank lines left behind by the removal down to a
/// single blank line. Tolerates both LF and CRLF line endings.
String cleanupMarkupBlock(
  String content,
  String beginMarkup,
  String endMarkup,
) {
  final escapedBegin = RegExp.escape(beginMarkup);
  final escapedEnd = RegExp.escape(endMarkup);

  final blockRegex = RegExp(
    r'[ \t]*' +
        escapedBegin +
        r'\r?\n(?:.*?\r?\n)?[ \t]*' +
        escapedEnd +
        r'\r?\n?',
    dotAll: true,
    multiLine: true,
  );

  final withoutBlock = content.replaceAll(blockRegex, '');

  return withoutBlock.replaceAll(RegExp(r'(?:\r?\n){3,}'), '\n\n');
}

/// Strips any leading line breaks (LF or CRLF).
String stripLeadingLineBreaks(String content) =>
    content.replaceFirst(RegExp(r'^(?:\r?\n)+'), '');

/// Escapes a value so it can be safely embedded in a double-quoted string
/// literal (CMake and C both treat `\` and `"` the same way).
String escapeQuotedString(String value) =>
    value.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
