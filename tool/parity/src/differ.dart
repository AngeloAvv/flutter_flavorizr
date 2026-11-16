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

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'tree.dart';

enum DifferenceKind { added, removed, changed }

class Difference {
  const Difference({
    required this.path,
    required this.kind,
    this.diff = '',
    this.reason,
  });

  final String path;
  final DifferenceKind kind;

  /// The lines that changed, prefixed with `-` (golden) and `+` (actual).
  final String diff;

  /// Why this difference is intended; null if nobody vouched for it.
  final String? reason;

  bool get isWhitelisted => reason != null;

  Difference _whitelisted(String reason) =>
      Difference(path: path, kind: kind, diff: diff, reason: reason);
}

class ParityReport {
  const ParityReport(this.differences);

  final List<Difference> differences;

  /// True when every difference is whitelisted.
  bool get isClean => differences.every((d) => d.isWhitelisted);

  String describe() {
    final buffer = StringBuffer();
    for (final d in differences) {
      final suffix = d.isWhitelisted ? ' (whitelisted: ${d.reason})' : '';
      buffer.writeln('${d.kind.name.toUpperCase()} ${d.path}$suffix');
      if (d.diff.isNotEmpty) {
        buffer.writeln(
          d.diff.trimRight().split('\n').map((line) => '    $line').join('\n'),
        );
      }
    }
    return buffer.toString();
  }
}

/// Per-file permission to differ from the golden, each with the reason why.
class Whitelist {
  const Whitelist._(this._entries);

  const Whitelist.empty() : _entries = const [];

  /// Parses a YAML list of `{path: <glob>, reason: <text>}` entries.
  factory Whitelist.parse(String yaml) {
    final document = loadYaml(yaml);
    if (document == null) return const Whitelist.empty();
    if (document is! YamlList) {
      throw const FormatException('The whitelist must be a list of entries');
    }

    return Whitelist._([
      for (final entry in document)
        () {
          final path = entry is YamlMap ? entry['path'] : null;
          final reason = entry is YamlMap ? entry['reason'] : null;
          if (path is! String || path.trim().isEmpty) {
            throw FormatException('Whitelist entry without path: $entry');
          }
          if (reason is! String || reason.trim().isEmpty) {
            throw FormatException(
              'Whitelist entry "$path" needs a reason: '
              'say why the difference is intended',
            );
          }
          return (pattern: globToRegExp(path), reason: reason.trim());
        }(),
    ]);
  }

  final List<({RegExp pattern, String reason})> _entries;

  String? reasonFor(String path) {
    for (final entry in _entries) {
      if (entry.pattern.hasMatch(path)) return entry.reason;
    }
    return null;
  }
}

/// Compares two normalized trees, see [normalizeTree].
ParityReport compareTrees(
  Directory golden,
  Directory actual, {
  Whitelist whitelist = const Whitelist.empty(),
}) {
  final expected = _read(golden);
  final found = _read(actual);

  final differences = <Difference>[];
  for (final path in {...expected.keys, ...found.keys}.toList()..sort()) {
    final before = expected[path];
    final after = found[path];

    final difference = switch ((before, after)) {
      (null, final String _) => Difference(
        path: path,
        kind: DifferenceKind.added,
      ),
      (final String _, null) => Difference(
        path: path,
        kind: DifferenceKind.removed,
      ),
      (final String a, final String b) when a != b => Difference(
        path: path,
        kind: DifferenceKind.changed,
        diff: _lineDiff(a, b),
      ),
      _ => null,
    };
    if (difference == null) continue;

    final reason = whitelist.reasonFor(path);
    differences.add(
      reason == null ? difference : difference._whitelisted(reason),
    );
  }

  return ParityReport(differences);
}

Map<String, String> _read(Directory root) => {
  for (final file in root.listSync(recursive: true).whereType<File>())
    p.posix.joinAll(p.split(p.relative(file.path, from: root.path))): file
        .readAsStringSync(),
};

/// Lines removed from [a] and added by [b], found through the longest common
/// subsequence. Context lines are left out on purpose.
String _lineDiff(String a, String b) {
  final left = a.split('\n');
  final right = b.split('\n');

  final lcs = List.generate(
    left.length + 1,
    (_) => List.filled(right.length + 1, 0),
  );
  for (var i = left.length - 1; i >= 0; i--) {
    for (var j = right.length - 1; j >= 0; j--) {
      lcs[i][j] = left[i] == right[j]
          ? lcs[i + 1][j + 1] + 1
          : lcs[i + 1][j] >= lcs[i][j + 1]
          ? lcs[i + 1][j]
          : lcs[i][j + 1];
    }
  }

  final buffer = StringBuffer();
  var i = 0;
  var j = 0;
  while (i < left.length && j < right.length) {
    if (left[i] == right[j]) {
      i++;
      j++;
    } else if (lcs[i + 1][j] >= lcs[i][j + 1]) {
      buffer.writeln('-${left[i++]}');
    } else {
      buffer.writeln('+${right[j++]}');
    }
  }
  while (i < left.length) {
    buffer.writeln('-${left[i++]}');
  }
  while (j < right.length) {
    buffer.writeln('+${right[j++]}');
  }
  return buffer.toString();
}
