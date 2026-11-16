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
/// left exactly as the user wrote them. Nothing is parsed into a tree and
/// serialized again.
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

    return source.replaceRange(label.valueStart, label.valueEnd, appLabel);
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

      final tag = _scanTag(source, event);
      final attribute = event.attributes
          .where((attribute) => attribute.name == _labelAttribute)
          .firstOrNull;
      final range = tag[_labelAttribute];

      if (attribute == null || range == null) {
        throw MalformedResourceException(source);
      }

      return _Label(attribute.value, range.$1, range.$2);
    }

    throw MalformedResourceException(source);
  }

  /// Maps the name of each attribute of the start tag of [element] to the
  /// range of its raw value, excluding the quotes, in [source]. When a name
  /// repeats, the first one wins.
  static Map<String, (int, int)> _scanTag(
    String source,
    XmlStartElementEvent element,
  ) {
    final end = element.stop!;
    var position = element.start! + '<'.length + element.name.length;
    final ranges = <String, (int, int)>{};

    bool isSpace(int index) => ' \t\r\n'.contains(source[index]);

    void skipSpaces() {
      while (position < end && isSpace(position)) {
        position++;
      }
    }

    while (position < end) {
      skipSpaces();

      if (position >= end ||
          source[position] == '>' ||
          source[position] == '/') {
        break;
      }

      final nameStart = position;
      while (position < end && !isSpace(position) && source[position] != '=') {
        position++;
      }
      final name = source.substring(nameStart, position);

      skipSpaces();
      // The document is well formed, so an attribute always has a value.
      position++; // `=`
      skipSpaces();

      final quote = source[position];
      final valueStart = position + 1;
      final valueEnd = source.indexOf(quote, valueStart);

      ranges.putIfAbsent(name, () => (valueStart, valueEnd));
      position = valueEnd + 1;
    }

    return ranges;
  }
}

class _Label {
  final String value;
  final int valueStart;
  final int valueEnd;

  const _Label(this.value, this.valueStart, this.valueEnd);
}
