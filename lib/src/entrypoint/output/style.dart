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

import 'package:flutter_flavorizr/src/engine/shadow/workspace_diff.dart';

/// Colours text with ANSI SGR codes, or leaves it as it is.
///
/// It has no dependency on purpose: eight codes are all the output needs, and
/// whether they are used is decided once, by `OutputEnvironment.color`.
final class Style {
  /// Whether the text is coloured.
  final bool color;

  /// A style that colours when [color] is `true`.
  const Style({required this.color});

  /// A style that never colours.
  const Style.none() : color = false;

  String _wrap(String text, int open, int close) =>
      color ? '\x1B[${open}m$text\x1B[${close}m' : text;

  /// [text] in green: something that was added or went well.
  String green(String text) => _wrap(text, 32, 39);

  /// [text] in red: something that was removed or went wrong.
  String red(String text) => _wrap(text, 31, 39);

  /// [text] in yellow: something that changed, or deserves attention.
  String yellow(String text) => _wrap(text, 33, 39);

  /// [text] in cyan: a name worth spotting.
  String cyan(String text) => _wrap(text, 36, 39);

  /// [text] in bold.
  String bold(String text) => _wrap(text, 1, 22);

  /// [text] faint: what is not the point, like a duration.
  String dim(String text) => _wrap(text, 2, 22);

  /// The description of [change], coloured by what happened to the file: green
  /// when added, yellow when changed, red when deleted or in conflict.
  String change(FileChange change) {
    final line = change.describe();

    if (change.disposition == ChangeDisposition.conflict ||
        change.disposition == ChangeDisposition.blocked) {
      return red(line);
    }

    return switch (change.kind) {
      ChangeKind.added => green(line),
      ChangeKind.modified => yellow(line),
      ChangeKind.deleted => red(line),
    };
  }

  /// [text] with each line that starts with `+`, `~` or `-` coloured as a
  /// diff: the lines of the flavors that were added, changed or removed.
  String diff(String text) {
    if (!color) return text;

    return text
        .split('\n')
        .map(
          (line) => switch (line.isEmpty ? '' : line[0]) {
            '+' => green(line),
            '~' => yellow(line),
            '-' => red(line),
            _ => line,
          },
        )
        .join('\n');
  }
}
