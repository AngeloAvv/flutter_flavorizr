/*
 * Copyright (c) 2021 MyLittleSuite
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

import 'package:flutter_flavorizr/exception/malformed_resource_exception.dart';
import 'package:flutter_flavorizr/processors/commons/string_processor.dart';
import 'package:xml/xml.dart';

class IOSPListProcessor extends StringProcessor {
  IOSPListProcessor({String input}) : super(input: input);

  @override
  String execute() {
    XmlDocument document = XmlDocument.parse(this.input);
    XmlElement root = document.rootElement.children
        .where((XmlNode node) => node is XmlElement)
        .first;

    _updateCFBundleName(root);
    _updateUILaunchStoryboardName(root);

    return document.toXmlString(pretty: true);
  }

  void _updateCFBundleName(XmlElement root) => _updatePListValueAtKey(
        root,
        'CFBundleName',
        '\$(BUNDLE_NAME)',
      );

  void _updateUILaunchStoryboardName(XmlElement root) => _updatePListValueAtKey(
        root,
        'UILaunchStoryboardName',
        '\$(ASSET_PREFIX)LaunchScreen',
      );

  void _updatePListValueAtKey(XmlElement root, String key, String value) {
    Iterable<XmlNode> keys =
        root.children.where((e) => e is XmlElement && e.name.local == 'key');
    if (keys.isEmpty) {
      throw MalformedResourceException(input);
    }

    XmlElement element =
        keys.firstWhere((XmlNode e) => e.text == key, orElse: () => null);
    if (element == null) {
      throw MalformedResourceException(input);
    }

    XmlElement xmlValue = element.following?.firstWhere(
        (XmlNode e) => e is XmlElement && e.name.local == 'string',
        orElse: () => null);
    if (xmlValue == null) {
      throw MalformedResourceException(input);
    }

    XmlText xmlText = xmlValue.firstChild;
    xmlText.text = value;
  }

  @override
  String toString() => 'IOSPListProcessor';
}
