import 'package:crypto/crypto.dart';

final _uuidPattern = RegExp(r'\b[0-9A-F]{24}\b');
final _entryStart = RegExp(r'^\t\t([0-9A-F]{24}) ');

/// Rewrites every object UUID of a `project.pbxproj` with an identifier derived
/// from the object's structural path, then restores Xcode's ordering of each
/// section (entries sorted by UUID).
///
/// The structural path of an object is the chain of fields and list indexes
/// that leads to it from `rootObject`, following the file's own field order.
/// Objects not reachable from `rootObject` are named after their `isa` and
/// their human readable fields, numbered in case of duplicates.
String normalizePbxproj(String content) {
  final document = _PlistParser(content).parse();
  if (document is! Map) return content;

  final objects = document['objects'];
  final root = document['rootObject'];
  if (objects is! Map || root is! String) return content;

  final paths = <String, String>{};
  late void Function(Object?, String) walk;

  void visit(String uuid, String path) {
    paths[uuid] = path;
    walk(objects[uuid], path);
  }

  void follow(String uuid, String path) {
    if (objects.containsKey(uuid) && !paths.containsKey(uuid)) {
      visit(uuid, path);
    }
  }

  walk = (Object? value, String path) {
    if (value is String) {
      follow(value, path);
    } else if (value is List) {
      for (var i = 0; i < value.length; i++) {
        final item = value[i];
        item is String ? follow(item, '$path[$i]') : walk(item, '$path[$i]');
      }
    } else if (value is Map) {
      var index = 0;
      for (final entry in value.entries) {
        final key = entry.key as String;
        if (objects.containsKey(key)) {
          follow(key, '$path/{key$index}');
          walk(entry.value, '$path/{key$index}');
        } else {
          walk(entry.value, '$path/$key');
        }
        index++;
      }
    }
  };

  visit(root, 'root');
  _nameOrphans(objects, paths);

  final renamed = content.replaceAllMapped(_uuidPattern, (match) {
    final path = paths[match.group(0)];
    return path == null ? match.group(0)! : _identifierFor(path);
  });

  return _sortSections(renamed);
}

void _nameOrphans(Map objects, Map<String, String> paths) {
  final orphans =
      objects.keys.cast<String>().where((uuid) => !paths.containsKey(uuid)).map(
        (uuid) {
          final object = objects[uuid] as Map;
          final label = [
            object['isa'],
            object['name'],
            object['path'],
            object['productName'],
          ].whereType<String>().join('|');
          return (uuid: uuid, label: label);
        },
      ).toList()..sort((a, b) => a.label.compareTo(b.label));

  final seen = <String, int>{};
  for (final orphan in orphans) {
    final n = seen.update(orphan.label, (n) => n + 1, ifAbsent: () => 0);
    paths[orphan.uuid] = 'orphan/${orphan.label}#$n';
  }
}

String _identifierFor(String path) =>
    sha1.convert(path.codeUnits).toString().substring(0, 24).toUpperCase();

String _sortSections(String content) {
  final output = <String>[];
  List<List<String>>? entries;

  void flush() {
    if (entries == null) return;
    entries!.sort((a, b) => a.first.trim().compareTo(b.first.trim()));
    output.addAll(entries!.expand((lines) => lines));
    entries = null;
  }

  for (final line in content.split('\n')) {
    if (line.startsWith('/* Begin ') && line.endsWith(' section */')) {
      output.add(line);
      entries = [];
    } else if (line.startsWith('/* End ') && line.endsWith(' section */')) {
      flush();
      output.add(line);
    } else if (entries != null) {
      if (_entryStart.hasMatch(line) || entries!.isEmpty) {
        entries!.add([line]);
      } else {
        entries!.last.add(line);
      }
    } else {
      output.add(line);
    }
  }

  return output.join('\n');
}

/// A minimal parser for the OpenStep plist dialect used by Xcode projects.
class _PlistParser {
  _PlistParser(this._text);

  final String _text;
  int _i = 0;

  Object? parse() {
    _skip();
    return _value();
  }

  Object? _value() {
    _skip();
    if (_i >= _text.length) return null;

    switch (_text[_i]) {
      case '{':
        _i++;
        final map = <String, Object?>{};
        while (true) {
          _skip();
          if (_text[_i] == '}') {
            _i++;
            return map;
          }
          final key = _string();
          _skip();
          _expect('=');
          map[key] = _value();
          _skip();
          _expect(';');
        }
      case '(':
        _i++;
        final list = <Object?>[];
        while (true) {
          _skip();
          if (_text[_i] == ')') {
            _i++;
            return list;
          }
          list.add(_value());
          _skip();
          if (_text[_i] == ',') _i++;
        }
      default:
        return _string();
    }
  }

  String _string() {
    if (_text[_i] == '"') {
      final buffer = StringBuffer();
      _i++;
      while (_text[_i] != '"') {
        if (_text[_i] == r'\') _i++;
        buffer.write(_text[_i++]);
      }
      _i++;
      return buffer.toString();
    }

    final start = _i;
    while (_i < _text.length && _bare.hasMatch(_text[_i])) {
      _i++;
    }
    if (start == _i) {
      throw FormatException('Unexpected "${_text[_i]}"', _text, _i);
    }
    return _text.substring(start, _i);
  }

  static final _bare = RegExp(r'[A-Za-z0-9_$/.\-:+@]');

  void _expect(String char) {
    if (_text[_i] != char) {
      throw FormatException('Expected "$char"', _text, _i);
    }
    _i++;
  }

  void _skip() {
    while (_i < _text.length) {
      if (_text[_i].trim().isEmpty) {
        _i++;
      } else if (_text.startsWith('/*', _i)) {
        _i = _text.indexOf('*/', _i) + 2;
      } else if (_text.startsWith('//', _i)) {
        final end = _text.indexOf('\n', _i);
        _i = end == -1 ? _text.length : end + 1;
      } else {
        break;
      }
    }
  }
}
