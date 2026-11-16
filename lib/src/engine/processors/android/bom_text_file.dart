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

import 'dart:convert';
import 'dart:io';

/// Reads and writes a UTF-8 text file of the user without losing its byte
/// order mark, which decoding drops, so that a patched file is otherwise
/// written back byte for byte.
abstract final class BomTextFile {
  static const List<int> _bom = [0xef, 0xbb, 0xbf];

  /// Reads [file]: its text, without the byte order mark, and whether it had
  /// one.
  static Future<({String text, bool hasBom})> read(File file) async {
    final bytes = await file.readAsBytes();
    final hasBom =
        bytes.length >= _bom.length &&
        _bom.indexed.every((entry) => bytes[entry.$1] == entry.$2);

    return (
      text: utf8.decode(hasBom ? bytes.sublist(_bom.length) : bytes),
      hasBom: hasBom,
    );
  }

  /// Writes [text] to [file], preceded by a byte order mark when [hasBom].
  static Future<void> write(File file, String text, {required bool hasBom}) =>
      file.writeAsBytes([if (hasBom) ..._bom, ...utf8.encode(text)]);
}
