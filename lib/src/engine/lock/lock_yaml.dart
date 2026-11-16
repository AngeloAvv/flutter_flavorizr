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

/// A minimal YAML emitter with a single, stable output for a given tree.
///
/// A tree is made of `Map<String, Object?>`, `List<String>`, `String` and `int`
/// nodes. Mapping keys are always written in code unit order, the indentation
/// is two spaces, line endings are `\n` and nothing depends on the machine,
/// the locale or the time. The output is valid YAML that `loadYaml` reads back
/// to the same strings.
abstract final class LockYaml {
  /// Writes the mapping [root], one `key: value` per line.
  static String emit(Map<String, Object?> root) {
    final buffer = StringBuffer();

    _emitMap(buffer, root, 0);

    return buffer.toString();
  }

  static void _emitMap(
    StringBuffer buffer,
    Map<String, Object?> map,
    int indent,
  ) {
    final pad = ' ' * indent;

    for (final key in map.keys.toList()..sort()) {
      final value = map[key];

      switch (value) {
        case int():
          buffer.writeln('$pad${scalar(key)}: $value');
        case String():
          buffer.writeln('$pad${scalar(key)}: ${scalar(value)}');
        case Map<String, Object?>():
          if (value.isEmpty) {
            buffer.writeln('$pad${scalar(key)}: {}');
          } else {
            buffer.writeln('$pad${scalar(key)}:');
            _emitMap(buffer, value, indent + 2);
          }
        case List<String>():
          if (value.isEmpty) {
            buffer.writeln('$pad${scalar(key)}: []');
          } else {
            buffer.writeln('$pad${scalar(key)}:');
            for (final item in value) {
              buffer.writeln('$pad  - ${scalar(item)}');
            }
          }
        default:
          throw ArgumentError.value(value, key, 'unsupported node');
      }
    }
  }

  // Plain scalars start with a letter, a digit, `_`, `.` or `/` and continue
  // with characters that never have a meaning in YAML flow or block syntax.
  static final _plain = RegExp(r'^[A-Za-z0-9_./][A-Za-z0-9_./+:@-]*$');

  // What a YAML 1.2 core schema resolves to something other than a string.
  static final _number = RegExp(
    r'^(\.[0-9]+|[0-9]+(\.[0-9]*)?)([eE][-+]?[0-9]+)?$|^0[xo][0-9A-Fa-f]+$',
  );

  static const _reserved = {
    'true',
    'false',
    'null',
    'yes',
    'no',
    'on',
    'off',
    'y',
    'n',
    '.inf',
    '.nan',
  };

  /// Writes [value] as a YAML scalar: plain when that is safe, double quoted
  /// otherwise.
  static String scalar(String value) {
    if (_plain.hasMatch(value) &&
        !value.endsWith(':') &&
        !_number.hasMatch(value) &&
        !_reserved.contains(value.toLowerCase())) {
      return value;
    }

    final escaped = StringBuffer('"');

    for (final rune in value.runes) {
      switch (rune) {
        case 0x22:
          escaped.write(r'\"');
        case 0x5C:
          escaped.write(r'\\');
        case 0x0A:
          escaped.write(r'\n');
        case 0x0D:
          escaped.write(r'\r');
        case 0x09:
          escaped.write(r'\t');
        case < 0x20 || 0x7F || 0x85 || 0x2028 || 0x2029:
          escaped.write('\\u${rune.toRadixString(16).padLeft(4, '0')}');
        default:
          escaped.writeCharCode(rune);
      }
    }

    return (escaped..write('"')).toString();
  }
}
