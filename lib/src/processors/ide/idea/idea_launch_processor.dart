/*
 * Copyright (c) 2023 Angelo Cassano
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

import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:flutter_flavorizr/src/processors/commons/string_processor.dart';
import 'package:xml/xml.dart';

class IdeaLaunchProcessor extends StringProcessor {
  final String _flavorName;

  IdeaLaunchProcessor(
    this._flavorName, {
    String? input,
    required Flavorizr config,
  }) : super(
          input: input,
          config: config,
        );

  @override
  String toString() => 'IdeaLaunchProcessor';

  @override
  String execute() {
    final builder = XmlBuilder();

    builder.element('component',
        attributes: {'name': 'ProjectRunConfigurationManager'}, nest: () {
      builder.element('configuration', attributes: {
        'default': 'false',
        'name': 'main_$_flavorName.dart',
        'type': 'FlutterRunConfigurationType',
        'factoryName': 'Flutter',
      }, nest: () {
        builder.element('option', attributes: {
          'name': 'buildFlavor',
          'value': _flavorName,
        });

        builder.element('option', attributes: {
          'name': 'filePath',
          'value': '\$PROJECT_DIR\$/lib/main_$_flavorName.dart',
        });

        builder.element('method', attributes: {
          'v': '2',
        });
      });
    });

    return builder.buildDocument().toXmlString(pretty: true);
  }
}
