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

import 'package:flutter_flavorizr/src/exception/malformed_resource_exception.dart';
import 'package:xml/xml.dart';
import 'package:xml/xml_events.dart';

/// The format preserving edits flavorizr makes to `AndroidManifest.xml`.
///
/// The only part of the manifest flavorizr owns is the `android:label`
/// attribute of the first `<application>` element, which has to point to the
/// `app_name` resource that every flavor defines. An edit replaces the value of
/// that attribute in the source text and nothing else: indentation, line
/// endings, comments, quotes, attribute order and every other attribute are
/// left exactly as the user wrote them. The document is parsed to be validated
/// and to find the attribute, never serialized again.
abstract final class AndroidManifestEditor {
  /// The value `android:label` is set to.
  static const String appLabel = '@string/app_name';

  static const String _applicationElement = 'application';
  static const String _labelAttribute = 'android:label';

  /// Returns [source] with the label of the application pointing to
  /// [appLabel].
  ///
  /// [source] is returned as it is when the label already points to it.
  ///
  /// Throws a [MalformedResourceException] when the manifest has no
  /// `<application>` element, or the element has no `android:label`, and an
  /// [XmlException] when it is not a well formed XML document.
  static String withAppLabel(String source) {
    final label = _findLabel(source);

    if (label.value == appLabel) return source;

    return source.replaceRange(label.start, label.end, appLabel);
  }

  /// Returns the content of [source] flavorizr owns, which is the value of the
  /// label of the application. It is what the lock hashes for the manifest, so
  /// that whatever else the user edits is never drift.
  ///
  /// Throws like [withAppLabel].
  static String ownedContent(String source) => _findLabel(source).value;

  static _Label _findLabel(String source) {
    // The event parser is lenient: a document that is not well formed must
    // fail like it does when the manifest is parsed into a tree.
    XmlDocument.parse(source);

    for (final event in parseEvents(source, withLocation: true)) {
      if (event is! XmlStartElementEvent || event.name != _applicationElement) {
        continue;
      }

      final attribute = event.attributes
          .where((attribute) => attribute.name == _labelAttribute)
          .firstOrNull;
      final span = attribute == null ? null : _labelSpan(source, event);

      if (attribute == null || span == null) {
        throw MalformedResourceException(source);
      }

      return _Label(attribute.value, span.$1, span.$2);
    }

    throw MalformedResourceException(source);
  }

  /// The range of the raw value, quotes excluded, of the first `android:label`
  /// attribute of the start tag of [element] in [source], or `null` when the
  /// tag cannot be read as a sequence of `name="value"` pairs.
  ///
  /// It reads the text of the tag and nothing else, so it always moves forward
  /// and stops at the end of the tag.
  static (int, int)? _labelSpan(String source, XmlStartElementEvent element) {
    final end = element.stop!;
    var position = element.start! + '<'.length + element.name.length;

    void skipSpaces() {
      while (position < end && _isSpace(source.codeUnitAt(position))) {
        position++;
      }
    }

    while (true) {
      skipSpaces();

      if (position >= end || '>/'.contains(source[position])) return null;

      final nameStart = position;
      while (position < end &&
          !_isSpace(source.codeUnitAt(position)) &&
          source[position] != '=') {
        position++;
      }
      final name = source.substring(nameStart, position);

      skipSpaces();
      if (position >= end || source[position] != '=') return null;
      position++;
      skipSpaces();

      if (position >= end || !'"\''.contains(source[position])) return null;

      final valueStart = position + 1;
      final valueEnd = source.indexOf(source[position], valueStart);

      if (valueEnd < 0 || valueEnd >= end) return null;
      if (name == _labelAttribute) return (valueStart, valueEnd);

      position = valueEnd + 1;
    }
  }

  /// Whether [codeUnit] separates the parts of a tag, as far as the XML parser
  /// is concerned: it accepts every Unicode white space.
  static bool _isSpace(int codeUnit) =>
      (codeUnit >= 0x09 && codeUnit <= 0x0d) ||
      codeUnit == 0x20 ||
      codeUnit == 0x85 ||
      codeUnit == 0xa0 ||
      codeUnit == 0x1680 ||
      (codeUnit >= 0x2000 && codeUnit <= 0x200a) ||
      codeUnit == 0x2028 ||
      codeUnit == 0x2029 ||
      codeUnit == 0x202f ||
      codeUnit == 0x205f ||
      codeUnit == 0x3000 ||
      codeUnit == 0xfeff;
}

/// The label of the application: its decoded [value] and where its raw value
/// lies in the source, as the range [start] to [end] (exclusive).
final class _Label {
  final String value;
  final int start;
  final int end;

  const _Label(this.value, this.start, this.end);
}
