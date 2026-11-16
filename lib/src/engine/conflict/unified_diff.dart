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

import 'dart:typed_data';

/// The most cells of the table of the longest common subsequence: bigger
/// differences are shown as a whole replacement instead of a minimal edit, so
/// that a huge generated file never takes unbounded memory or time.
const _maxTableCells = 4000000;

const _reset = '\x1B[0m';
const _bold = '\x1B[1m';
const _red = '\x1B[31m';
const _green = '\x1B[32m';
const _cyan = '\x1B[36m';

/// Renders the differences between [oldText] and [newText] as a unified diff,
/// or an empty string when they are identical.
///
/// [oldLabel] and [newLabel] name the two sides in the `---` and `+++` lines.
/// Each hunk holds [context] unchanged lines around the changes. With [color],
/// the output carries ANSI codes: bold headers, cyan hunk markers, red removals
/// and green additions.
///
/// A line is compared together with its line terminator, so a file that only
/// differs in its final newline is not reported as identical.
String unifiedDiff({
  required String oldText,
  required String newText,
  required String oldLabel,
  required String newLabel,
  int context = 3,
  bool color = false,
}) {
  final oldLines = _split(oldText);
  final newLines = _split(newText);
  final edits = _edits(oldLines, newLines);

  if (edits.every((edit) => edit.kind == _Kind.same)) return '';

  String paint(String code, String text) =>
      color ? '$code$text$_reset' : text;

  final out = StringBuffer()
    ..writeln(paint(_bold, '--- $oldLabel'))
    ..writeln(paint(_bold, '+++ $newLabel'));

  for (final hunk in _hunks(edits, context)) {
    out.writeln(paint(_cyan, hunk.header));

    for (final edit in hunk.edits) {
      final line = edit.line;
      final text = line.endsWith('\n')
          ? line.substring(0, line.length - 1)
          : line;
      final (marker, code) = switch (edit.kind) {
        _Kind.same => (' ', null),
        _Kind.removed => ('-', _red),
        _Kind.added => ('+', _green),
      };
      final shown = '$marker$text';

      out.writeln(code == null ? shown : paint(code, shown));

      if (!line.endsWith('\n')) {
        out.writeln('\\ No newline at end of file');
      }
    }
  }

  return out.toString();
}

/// Splits [text] in lines that keep their `\n`, so that the last one tells
/// whether the text ends with a newline.
List<String> _split(String text) {
  final lines = <String>[];
  var start = 0;

  while (start < text.length) {
    final end = text.indexOf('\n', start);

    if (end == -1) {
      lines.add(text.substring(start));
      break;
    }

    lines.add(text.substring(start, end + 1));
    start = end + 1;
  }

  return lines;
}

enum _Kind { same, removed, added }

class _Edit {
  final _Kind kind;
  final String line;

  const _Edit(this.kind, this.line);
}

/// The sequence of edits that turns [a] into [b].
List<_Edit> _edits(List<String> a, List<String> b) {
  var prefix = 0;

  while (prefix < a.length && prefix < b.length && a[prefix] == b[prefix]) {
    prefix++;
  }

  var suffix = 0;

  while (suffix < a.length - prefix &&
      suffix < b.length - prefix &&
      a[a.length - 1 - suffix] == b[b.length - 1 - suffix]) {
    suffix++;
  }

  final middleA = a.sublist(prefix, a.length - suffix);
  final middleB = b.sublist(prefix, b.length - suffix);

  return [
    for (final line in a.take(prefix)) _Edit(_Kind.same, line),
    ..._middleEdits(middleA, middleB),
    for (final line in a.skip(a.length - suffix)) _Edit(_Kind.same, line),
  ];
}

/// The edits between two sequences that share no first and no last line, taken
/// from their longest common subsequence.
List<_Edit> _middleEdits(List<String> a, List<String> b) {
  final replacement = [
    for (final line in a) _Edit(_Kind.removed, line),
    for (final line in b) _Edit(_Kind.added, line),
  ];

  if (a.isEmpty || b.isEmpty) return replacement;

  final width = b.length + 1;

  if ((a.length + 1) * width > _maxTableCells) return replacement;

  // length[i * width + j] is the length of the longest common subsequence of
  // a[i..] and b[j..].
  final length = Uint32List((a.length + 1) * width);

  for (var i = a.length - 1; i >= 0; i--) {
    for (var j = b.length - 1; j >= 0; j--) {
      length[i * width + j] = a[i] == b[j]
          ? length[(i + 1) * width + j + 1] + 1
          : length[(i + 1) * width + j] >= length[i * width + j + 1]
          ? length[(i + 1) * width + j]
          : length[i * width + j + 1];
    }
  }

  final edits = <_Edit>[];
  var i = 0;
  var j = 0;

  while (i < a.length && j < b.length) {
    if (a[i] == b[j]) {
      edits.add(_Edit(_Kind.same, a[i]));
      i++;
      j++;
    } else if (length[(i + 1) * width + j] >= length[i * width + j + 1]) {
      edits.add(_Edit(_Kind.removed, a[i++]));
    } else {
      edits.add(_Edit(_Kind.added, b[j++]));
    }
  }

  while (i < a.length) {
    edits.add(_Edit(_Kind.removed, a[i++]));
  }

  while (j < b.length) {
    edits.add(_Edit(_Kind.added, b[j++]));
  }

  return edits;
}

class _Hunk {
  final String header;
  final List<_Edit> edits;

  const _Hunk(this.header, this.edits);
}

/// Groups [edits] in hunks of changes with [context] lines around them, merging
/// the hunks whose context would overlap.
List<_Hunk> _hunks(List<_Edit> edits, int context) {
  final changed = [
    for (var i = 0; i < edits.length; i++)
      if (edits[i].kind != _Kind.same) i,
  ];
  final hunks = <_Hunk>[];
  var index = 0;

  while (index < changed.length) {
    var last = changed[index];
    var next = index + 1;

    // Changes whose contexts touch or overlap belong to the same hunk.
    while (next < changed.length && changed[next] - last <= 2 * context + 1) {
      last = changed[next++];
    }

    final from = (changed[index] - context).clamp(0, edits.length);
    final to = (last + context + 1).clamp(0, edits.length);
    final slice = edits.sublist(from, to);

    var oldStart = 0;
    var newStart = 0;

    for (final edit in edits.take(from)) {
      if (edit.kind != _Kind.added) oldStart++;
      if (edit.kind != _Kind.removed) newStart++;
    }

    final oldCount = slice.where((e) => e.kind != _Kind.added).length;
    final newCount = slice.where((e) => e.kind != _Kind.removed).length;

    hunks.add(
      _Hunk(
        '@@ -${_range(oldStart, oldCount)} +${_range(newStart, newCount)} @@',
        slice,
      ),
    );
    index = next;
  }

  return hunks;
}

/// The `start,count` of a hunk side. [before] is the number of lines of that
/// side that come before the hunk: an empty side starts at the line before it.
String _range(int before, int count) => switch (count) {
  0 => '$before,0',
  1 => '${before + 1}',
  _ => '${before + 1},$count',
};
