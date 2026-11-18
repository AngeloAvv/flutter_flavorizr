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

import 'package:collection/collection.dart';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'pbxproj_normalizer.dart';
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

typedef _Entry = ({
  RegExp pattern,
  String reason,
  bool onlyComments,
  RegExp? dropFromGolden,
  RegExp? moved,
  RegExp? ignore,
});

/// Per-file permission to differ from the golden, each with the reason why.
class Whitelist {
  const Whitelist._(this._entries);

  const Whitelist.empty() : _entries = const [];

  /// Parses a YAML list of `{path: <glob>, reason: <text>}` entries. An entry
  /// with `only-comments: true` covers a changed file only if it differs from
  /// the golden in its `/* ... */` annotations and in nothing else.
  ///
  /// Two more options say what else a `project.pbxproj` may differ in, and
  /// both are regular expressions:
  ///
  /// * `drop-from-golden` removes the lines of the golden that match, then
  ///   names the UUIDs of the golden again (see [normalizePbxproj]). It is what
  ///   the new output no longer has: the objects that went away, and the ones
  ///   that are named after their place in a list after them.
  /// * `moved` is for what the new output has in another place than the
  ///   golden, which names the UUIDs of everything after it differently. The
  ///   lines that match are left out of both files, which are named again, and
  ///   what was left out has to be the same in both (their UUIDs and comments
  ///   put aside), so that an object that is gone, or changed, is not hidden.
  /// * `ignore` removes what matches from both files before comparing them. It
  ///   is what the new output has more of, in the lines it shares with the
  ///   golden.
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
          return (
            pattern: globToRegExp(path),
            reason: reason.trim(),
            onlyComments: entry['only-comments'] == true,
            dropFromGolden: _optionalPattern(entry, 'drop-from-golden', path),
            moved: _optionalPattern(entry, 'moved', path),
            ignore: _optionalPattern(entry, 'ignore', path),
          );
        }(),
    ]);
  }

  static RegExp? _optionalPattern(YamlMap entry, String key, String path) {
    final value = entry[key];
    if (value == null) return null;
    if (value is! String || value.isEmpty) {
      throw FormatException(
        'Whitelist entry "$path": `$key` must be a non-empty regular expression',
      );
    }
    return RegExp(value, multiLine: true);
  }

  final List<_Entry> _entries;

  /// The reason a difference of [path] is intended, or null. [before] and
  /// [after] are the golden and the actual content of a changed file, null for
  /// a file that was added or removed.
  String? reasonFor(String path, {String? before, String? after}) {
    for (final entry in _entries) {
      if (!entry.pattern.hasMatch(path)) continue;
      final restricted =
          entry.onlyComments ||
          entry.dropFromGolden != null ||
          entry.moved != null ||
          entry.ignore != null;
      if (restricted &&
          (before == null || after == null || !_covers(entry, before, after))) {
        continue;
      }
      return entry.reason;
    }
    return null;
  }

  /// Whether [entry] vouches for a file that was [before] and is [after].
  static bool _covers(_Entry entry, String before, String after) {
    var left = before;
    var right = after;

    final drop = entry.dropFromGolden;
    if (drop != null) {
      left = normalizePbxproj(
        left.split('\n').where((line) => !drop.hasMatch(line)).join('\n'),
      );
    }

    final moved = entry.moved;
    if (moved != null) {
      final (kept: keptLeft, moved: movedLeft) = _split(left, moved);
      final (kept: keptRight, moved: movedRight) = _split(right, moved);

      if (!const ListEquality<String>().equals(
        _essence(left, moved),
        _essence(right, moved),
      )) {
        return false;
      }

      left = normalizePbxproj(keptLeft);
      right = normalizePbxproj(keptRight);
    }

    final ignore = entry.ignore;
    if (ignore != null) {
      left = left.replaceAll(ignore, '');
      right = right.replaceAll(ignore, '');
    }

    return entry.onlyComments
        ? _withoutComments(left) == _withoutComments(right)
        : left == right;
  }

  static ({String kept, List<int> moved}) _split(String content, RegExp moved) {
    final kept = <String>[];
    final away = <int>[];

    for (final (index, line) in content.split('\n').indexed) {
      if (moved.hasMatch(line)) {
        away.add(index);
      } else {
        kept.add(line);
      }
    }

    return (kept: kept.join('\n'), moved: away);
  }

  static final _uuid = RegExp(r'\b[0-9A-F]{24}(?:[0-9A-F]{8})?\b');
  static final _objectStart = RegExp(
    r'^\s*([0-9A-F]{24}(?:[0-9A-F]{8})?)(?: /\*.*?\*/)? = \{\s*$',
  );
  static final _definition = RegExp(
    r'^\s*([0-9A-F]{24}(?:[0-9A-F]{8})?)(?: /\*.*?\*/)? = \{isa = (\w+);(.*)\};\s*$',
  );
  static final _listing = RegExp(
    r'^\s*([0-9A-F]{24}(?:[0-9A-F]{8})?)(?: /\*.*?\*/)?,\s*$',
  );
  static final _listStart = RegExp(r'^\s*(\w+) = \(\s*$');
  static final _path = RegExp(r'\bpath = (?:"([^"]*)"|([^;"\s]+));');
  static final _fileRef = RegExp(
    r'\bfileRef = ([0-9A-F]{24}(?:[0-9A-F]{8})?)\b',
  );

  /// What the lines of [content] that match [moved] say, without where they
  /// are: no UUID and no annotation, but what each one refers to and the list
  /// of the object it is in. A build file says which file it builds, a listed
  /// entry the kind of object that lists it and what it lists. The result is
  /// sorted, so that a list may have them in another order.
  static List<String> _essence(String content, RegExp moved) {
    final lines = content.split('\n');
    final pathOf = <String, String>{};
    final buildFileOf = <String, String>{};

    for (final line in lines) {
      final definition = _definition.firstMatch(line);

      if (definition == null) continue;

      final uuid = definition.group(1)!;
      final body = definition.group(3)!;

      switch (definition.group(2)) {
        case 'PBXFileReference':
          final path = _path.firstMatch(body);

          pathOf[uuid] = path?.group(1) ?? path?.group(2) ?? '?';
        case 'PBXBuildFile':
          buildFileOf[uuid] = _fileRef.firstMatch(body)?.group(1) ?? '?';
      }
    }

    String named(String uuid) {
      final reference = buildFileOf[uuid];

      return reference != null
          ? 'build of ${pathOf[reference] ?? '?'}'
          : 'file ${pathOf[uuid] ?? '?'}';
    }

    String owner(int index) {
      String? list;

      for (var at = index - 1; at >= 0; at--) {
        list ??= _listStart.firstMatch(lines[at])?.group(1);

        if (_objectStart.hasMatch(lines[at])) {
          for (var next = at + 1; next < lines.length; next++) {
            final isa = RegExp(r'\bisa = (\w+);').firstMatch(lines[next]);

            if (isa != null) return '${isa.group(1)}.$list';
          }
        }
      }

      return '?';
    }

    return [
      for (final (index, line) in lines.indexed)
        if (moved.hasMatch(line))
          if (_definition.firstMatch(line) case final definition?)
            switch (definition.group(2)) {
              // The file it builds, and whatever else it says (settings...).
              'PBXBuildFile' =>
                'PBXBuildFile ${named(definition.group(1)!)} '
                    '${_withoutComments(definition.group(3)!).replaceAll(_fileRef, '').replaceAll(_uuid, 'UUID').trim()}',
              _ => _withoutComments(line).replaceAll(_uuid, 'UUID').trim(),
            }
          else if (_listing.firstMatch(line) case final listing?)
            '${owner(index)} lists ${named(listing.group(1)!)}'
          else
            _withoutComments(line).replaceAll(_uuid, 'UUID').trim(),
    ]..sort();
  }

  /// [content] without its `/* ... */` annotations, and the space before each.
  /// A quoted value is copied as it is, escapes included, as the ASCII plist
  /// grammar reads it, so that a `/* ... */` inside a shell script is content.
  static String _withoutComments(String content) {
    final result = StringBuffer();
    var i = 0;
    while (i < content.length) {
      final char = content[i];
      if (char == '"') {
        final start = i++;
        while (i < content.length && content[i] != '"') {
          i += content[i] == '\\' ? 2 : 1;
        }
        i = i < content.length ? i + 1 : content.length;
        result.write(content.substring(start, i));
      } else if (char == ' ' && content.startsWith('/*', i + 1)) {
        i++;
      } else if (content.startsWith('/*', i)) {
        final end = content.indexOf('*/', i + 2);
        if (end == -1) {
          result.write(content.substring(i));
          break;
        }
        i = end + 2;
      } else {
        result.write(char);
        i++;
      }
    }
    return result.toString();
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

    final reason = whitelist.reasonFor(path, before: before, after: after);
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
