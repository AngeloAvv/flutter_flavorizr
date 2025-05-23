// ignore_for_file: deprecated_member_use

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

import 'package:collection/collection.dart';
import 'package:flutter_flavorizr/src/exception/malformed_resource_exception.dart';
import 'package:flutter_flavorizr/src/processors/commons/string_processor.dart';
import 'package:xml/xml.dart';

class MacOSPListProcessor extends StringProcessor {
  MacOSPListProcessor({
    super.input,
    required super.config,
    required super.logger,
  });

  @override
  String execute() {
    logger.detail(
      '[$MacOSPListProcessor] Updating macOS PList file',
    );

    XmlDocument document = XmlDocument.parse(input!);
    XmlElement root =
        (document.rootElement.children.whereType<XmlElement>().first);

    _updateCFBundleName(root);

    final result = document.toXmlString(pretty: true);

    logger.detail(
      '[$MacOSPListProcessor] Updated macOS PList file',
      style: logger.theme.success,
    );

    return result;
  }

  void _updateCFBundleName(XmlElement root) => _updatePListValueAtKey(
        root,
        'CFBundleName',
        '\$(BUNDLE_NAME)',
      );

  void _updatePListValueAtKey(XmlElement root, String key, String value) {
    Iterable<XmlNode> keys =
        root.children.where((e) => e is XmlElement && e.name.local == 'key');
    if (keys.isEmpty) {
      throw MalformedResourceException(input!);
    }

    XmlNode? element = keys.firstWhereOrNull((XmlNode e) => e.text == key);
    if (element == null) {
      throw MalformedResourceException(input!);
    }

    XmlNode? xmlValue = element.following.firstWhereOrNull(
        (XmlNode e) => e is XmlElement && e.name.local == 'string');
    if (xmlValue == null) {
      throw MalformedResourceException(input!);
    }

    XmlText xmlText = xmlValue.firstChild as XmlText;
    xmlText.text = value;
  }

  @override
  String toString() => 'MacOSPListProcessor';
}
