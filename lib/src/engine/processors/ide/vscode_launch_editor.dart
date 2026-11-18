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

import 'dart:convert';

/// One value of a JSONC document, with where it is in the text.
final class _Json {
  /// Where the value starts, and the offset just after it.
  final int start;
  final int end;

  /// What the value is: a `Map`, a `List`, a `String`, a number, a `bool` or
  /// `null`.
  final Object? value;

  /// The members of an object, in order.
  final List<_Member> members;

  /// The items of an array, in order.
  final List<_Json> items;

  /// For an item of an array, the offset of the comma that follows it.
  int? commaAt;

  _Json(
    this.start,
    this.end,
    this.value, {
    this.members = const [],
    this.items = const [],
  });

  /// The value of the `name` member, when this is an object and it is text.
  String? get name {
    for (final member in members) {
      if (member.key == 'name' && member.value.value is String) {
        return member.value.value as String;
      }
    }

    return null;
  }
}

/// A key of an object and its value.
final class _Member {
  final String key;
  final _Json value;

  _Member(this.key, this.value);
}

/// Reads JSON the way VS Code does for `launch.json`: with comments, and with a
/// comma after the last item.
final class _JsoncReader {
  final String _source;
  int _at = 0;

  _JsoncReader(this._source);

  _Json read() {
    _skip();
    final value = _value();
    _skip();

    if (_at < _source.length) {
      throw _error('unexpected `${_source[_at]}`');
    }

    return value;
  }

  FormatException _error(String message) =>
      FormatException('$message at offset $_at', _source, _at);

  void _skip() {
    while (_at < _source.length) {
      final char = _source[_at];

      if (char == ' ' ||
          char == '\t' ||
          char == '\n' ||
          char == '\r' ||
          char == '﻿') {
        _at++;
      } else if (_source.startsWith('//', _at)) {
        while (_at < _source.length && _source[_at] != '\n') {
          _at++;
        }
      } else if (_source.startsWith('/*', _at)) {
        final close = _source.indexOf('*/', _at + 2);

        if (close < 0) throw _error('a comment that is not closed');

        _at = close + 2;
      } else {
        break;
      }
    }
  }

  _Json _value() {
    if (_at >= _source.length) throw _error('a value is missing');

    return switch (_source[_at]) {
      '{' => _object(),
      '[' => _array(),
      '"' => _string(),
      _ => _literal(),
    };
  }

  _Json _object() {
    final start = _at++;
    final members = <_Member>[];
    final value = <String, Object?>{};

    _skip();

    while (true) {
      if (_at < _source.length && _source[_at] == '}') {
        _at++;
        break;
      }

      if (_at >= _source.length || _source[_at] != '"') {
        throw _error('a key is expected');
      }

      final key = _string();

      _skip();
      _expect(':');
      _skip();

      final member = _value();

      members.add(_Member(key.value as String, member));
      value[key.value as String] = member.value;
      _skip();

      if (_at < _source.length && _source[_at] == ',') {
        _at++;
        _skip();
      } else if (_at >= _source.length || _source[_at] != '}') {
        throw _error('`,` or `}` is expected');
      }
    }

    return _Json(start, _at, value, members: members);
  }

  _Json _array() {
    final start = _at++;
    final items = <_Json>[];

    _skip();

    while (true) {
      if (_at < _source.length && _source[_at] == ']') {
        _at++;
        break;
      }

      final item = _value();

      items.add(item);
      _skip();

      if (_at < _source.length && _source[_at] == ',') {
        item.commaAt = _at++;
        _skip();
      } else if (_at >= _source.length || _source[_at] != ']') {
        throw _error('`,` or `]` is expected');
      }
    }

    return _Json(start, _at, [
      for (final item in items) item.value,
    ], items: items);
  }

  _Json _string() {
    final start = _at++;

    while (_at < _source.length && _source[_at] != '"') {
      _at += _source[_at] == r'\' ? 2 : 1;
    }

    if (_at >= _source.length) throw _error('a string that is not closed');

    _at++;

    return _Json(start, _at, jsonDecode(_source.substring(start, _at)));
  }

  _Json _literal() {
    final start = _at;

    while (_at < _source.length && !',]}/ \t\r\n'.contains(_source[_at])) {
      _at++;
    }

    try {
      return _Json(start, _at, jsonDecode(_source.substring(start, _at)));
    } on FormatException {
      throw _error('`${_source.substring(start, _at)}` is not a value');
    }
  }

  void _expect(String char) {
    if (_at >= _source.length || _source[_at] != char) {
      throw _error('`$char` is expected');
    }

    _at++;
  }
}

/// A change to a text: [start] to [end] is replaced with [text].
final class _Edit {
  final int start;
  final int end;
  final String text;

  _Edit(this.start, this.end, this.text);
}

/// Adds, replaces and removes the entries of `configurations` in a
/// `.vscode/launch.json`, and leaves the rest of the text as it is: the
/// comments, the entries of the user and the way the file is laid out.
///
/// The file is JSONC, which VS Code's own template has comments in, so it is not
/// decoded and written back: that would drop the comments. The text is read to
/// find where the entries are, and only those are edited.
abstract final class VsCodeLaunchEditor {
  static const _unit = '    ';

  /// The text of a `launch.json` that holds [entries].
  static String create(List<Map<String, Object?>> entries) =>
      '${const JsonEncoder.withIndent(_unit).convert({'version': '0.2.0', 'configurations': entries})}\n';

  /// [source] with the entries named like the ones of [entries] replaced by
  /// them, the ones that are not there added at the end of `configurations`,
  /// and the ones named in [remove] removed.
  ///
  /// An entry that is the same as the one that replaces it is not touched. The
  /// entries of the user, and everything that is not an entry, stay as they
  /// are.
  ///
  /// Throws a [FormatException] when [source] is not JSONC, or is not what a
  /// `launch.json` is: an object whose `configurations` is a list.
  static String edit(
    String source,
    List<Map<String, Object?>> entries, {
    Set<String> remove = const {},
  }) {
    final root = _JsoncReader(source).read();

    if (root.value is! Map) {
      throw FormatException('a launch.json is an object', source, root.start);
    }

    final configurations = root.members
        .where((member) => member.key == 'configurations')
        .firstOrNull
        ?.value;

    if (configurations == null) {
      return _addConfigurations(source, root, entries);
    }

    if (configurations.value is! List) {
      throw FormatException(
        '`configurations` is a list',
        source,
        configurations.start,
      );
    }

    final byName = {
      for (final entry in entries) entry['name'] as String: entry,
    };
    final seen = <String>{};
    final deleted = <_Json>[];
    final edits = <_Edit>[];
    final indent = _itemIndent(source, configurations);
    final step = _stepOf(source, configurations, indent);

    for (final item in configurations.items) {
      final name = item.name;
      final entry = byName[name];

      if (name == null || item.value is! Map) continue;

      if (entry == null) {
        if (remove.contains(name)) deleted.add(item);

        continue;
      }

      // The second entry of a name is a duplicate: only one is kept.
      if (!seen.add(name)) {
        deleted.add(item);
      } else if (!_same(item.value, entry)) {
        edits.add(_Edit(item.start, item.end, _render(entry, indent, step)));
      }
    }

    final survivors = [
      for (final item in configurations.items)
        if (!deleted.contains(item)) item,
    ];
    final added = [
      for (final entry in entries)
        if (!seen.contains(entry['name'])) entry,
    ];

    for (final item in deleted) {
      edits.addAll(_deletion(source, item));
    }

    _restoreCommas(source, configurations, survivors, deleted, added, edits);
    _append(source, configurations, survivors, added, indent, step, edits);

    return _apply(source, edits);
  }

  static bool _same(Object? a, Object? b) => jsonEncode(a) == jsonEncode(b);

  /// The text of an entry, laid out as the items of the list are.
  static String _render(
    Map<String, Object?> entry,
    String indent,
    String step,
  ) => JsonEncoder.withIndent(step)
      .convert(entry)
      .split('\n')
      .indexed
      .map((line) => line.$1 == 0 ? line.$2 : '$indent${line.$2}')
      .join('\n');

  /// The indentation of the items of [list]: the one of the first, when it
  /// starts a line, otherwise one step inside the line the list starts in.
  static String _itemIndent(String source, _Json list) {
    final first = list.items.firstOrNull;

    if (first != null && _startsLine(source, first.start)) {
      return _indentOf(source, first.start);
    }

    return '${_indentOf(source, list.start)}$_unit';
  }

  /// How far each level of the file is indented.
  static String _stepOf(String source, _Json list, String itemIndent) {
    final outer = _indentOf(source, list.start);

    return itemIndent.length > outer.length &&
            itemIndent.startsWith(outer) &&
            itemIndent.length - outer.length <= 8
        ? itemIndent.substring(outer.length)
        : _unit;
  }

  static bool _startsLine(String source, int offset) {
    var at = offset - 1;

    while (at >= 0 && (source[at] == ' ' || source[at] == '\t')) {
      at--;
    }

    return at < 0 || source[at] == '\n';
  }

  static int _lineStart(String source, int offset) {
    final newline = source.lastIndexOf('\n', offset - 1);

    return newline < 0 ? 0 : newline + 1;
  }

  /// The whitespace the line of [offset] starts with.
  static String _indentOf(String source, int offset) {
    final start = _lineStart(source, offset);
    var end = start;

    while (end < source.length && (source[end] == ' ' || source[end] == '\t')) {
      end++;
    }

    return source.substring(start, end);
  }

  /// The edit that removes [item]: its line when it has the line to itself,
  /// with the comma that follows it.
  static List<_Edit> _deletion(String source, _Json item) {
    var start = item.start;
    var end = item.commaAt != null ? item.commaAt! + 1 : item.end;
    final ownLine = _startsLine(source, item.start);

    // A comment between the item and its comma is not the item's: the two are
    // removed apart, and the comment stays.
    final comma = item.commaAt;

    if (comma != null && source.substring(item.end, comma).trim().isNotEmpty) {
      return [
        _Edit(ownLine ? _lineStart(source, item.start) : start, item.end, ''),
        _Edit(comma, comma + 1, ''),
      ];
    }

    if (ownLine) start = _lineStart(source, item.start);

    var tail = end;

    while (tail < source.length &&
        (source[tail] == ' ' || source[tail] == '\t')) {
      tail++;
    }

    if (ownLine && tail < source.length && source[tail] == '\r') tail++;

    if (ownLine && tail < source.length && source[tail] == '\n') {
      end = tail + 1;
    } else if (!ownLine) {
      end = tail;
    }

    return [_Edit(start, end, '')];
  }

  /// Keeps the commas of the list valid: the last item that is left has one
  /// only when something follows it or the file had one after its last item.
  static void _restoreCommas(
    String source,
    _Json list,
    List<_Json> survivors,
    List<_Json> deleted,
    List<Map<String, Object?>> added,
    List<_Edit> edits,
  ) {
    if (survivors.isEmpty || list.items.isEmpty) return;

    final last = survivors.last;
    final trailing = list.items.last.commaAt != null;

    if (added.isNotEmpty) return;

    if (last.commaAt != null && !trailing) {
      edits.add(_Edit(last.commaAt!, last.commaAt! + 1, ''));
    }
  }

  /// Adds [added] after the last item that is left.
  static void _append(
    String source,
    _Json list,
    List<_Json> survivors,
    List<Map<String, Object?>> added,
    String indent,
    String step,
    List<_Edit> edits,
  ) {
    if (added.isEmpty) return;

    final rendered = [
      for (final entry in added) '$indent${_render(entry, indent, step)}',
    ];

    if (survivors.isEmpty) {
      final inner = source.substring(list.start + 1, list.end - 1);
      final outer = _indentOf(source, list.start);

      if (inner.trim().isEmpty) {
        edits.add(
          _Edit(
            list.start + 1,
            list.end - 1,
            '\n${rendered.join(',\n')}\n$outer',
          ),
        );
      } else {
        edits.add(
          _Edit(list.start + 1, list.start + 1, '\n${rendered.join(',\n')},'),
        );
      }

      return;
    }

    final last = survivors.last;
    final trailing = list.items.last.commaAt != null;

    if (last.commaAt != null) {
      edits.add(
        _Edit(
          last.commaAt! + 1,
          last.commaAt! + 1,
          '\n${rendered.join(',\n')}${trailing ? ',' : ''}',
        ),
      );
    } else {
      edits.add(_Edit(last.end, last.end, ',\n${rendered.join(',\n')}'));
    }
  }

  /// A launch.json that has no `configurations`: they are added to its object.
  static String _addConfigurations(
    String source,
    _Json root,
    List<Map<String, Object?>> entries,
  ) {
    if (entries.isEmpty) return source;

    final last = root.members.lastOrNull?.value;
    final indent = last == null
        ? _unit
        : _indentOf(source, root.members.first.value.start);
    final member = _render({'configurations': entries}, indent, _unit);
    final text = member
        .substring(member.indexOf('{') + 1, member.lastIndexOf('}'))
        .trim();

    return _apply(source, [
      if (last == null)
        // Whatever is in the object, a comment included, stays.
        if (source.substring(root.start + 1, root.end - 1).trim().isEmpty)
          _Edit(root.start + 1, root.end - 1, '\n$indent$text\n')
        else
          _Edit(root.start + 1, root.start + 1, '\n$indent$text')
      else
        _Edit(last.end, last.end, ',\n$indent$text'),
    ]);
  }

  static String _apply(String source, List<_Edit> edits) {
    // From the end of the text to its start. Edits that start at the same
    // offset run the longer one first: a removal must not eat what an
    // insertion that starts there has just written.
    final ordered = [...edits]
      ..sort((a, b) {
        final byStart = b.start.compareTo(a.start);

        return byStart != 0 ? byStart : b.end.compareTo(a.end);
      });
    var result = source;

    for (final edit in ordered) {
      result = result.replaceRange(edit.start, edit.end, edit.text);
    }

    return result;
  }
}
