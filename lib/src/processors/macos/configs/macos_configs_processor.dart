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

import 'dart:collection';

import 'package:flutter_flavorizr/src/extensions/extensions_map.dart';
import 'package:flutter_flavorizr/src/extensions/extensions_string.dart';
import 'package:flutter_flavorizr/src/parser/models/flavors/darwin/enums.dart';
import 'package:flutter_flavorizr/src/parser/models/flavors/darwin/variable.dart';
import 'package:flutter_flavorizr/src/parser/models/flavors/flavor.dart';
import 'package:flutter_flavorizr/src/processors/commons/string_processor.dart';

class MacOSConfigsProcessor extends StringProcessor {
  final String _flavorName;
  final Flavor _flavor;
  final Target _target;

  MacOSConfigsProcessor(
    this._flavorName,
    this._flavor,
    this._target, {
    super.input,
    required super.config,
    required super.logger,
  });

  @override
  String execute() {
    final buffer = StringBuffer();

    logger.detail(
        '[$MacOSConfigsProcessor] Generating $_flavorName.${_target.name}.xcconfig');

    _appendIncludes(buffer);
    _appendBody(buffer);

    logger.detail(
      '[$MacOSConfigsProcessor] Generated $_flavorName.${_target.name}.xcconfig',
      style: logger.theme.success,
    );

    return buffer.toString();
  }

  void _appendIncludes(StringBuffer buffer) {
    buffer.writeln(
        '#include "../../Flutter/$_flavorName${_target.name.capitalize}.xcconfig"');
    buffer.writeln('#include "Warnings.xcconfig"');
  }

  void _appendBody(StringBuffer buffer) {
    final Map<String, Variable> variables = LinkedHashMap.from({
      'ASSET_PREFIX': Variable(value: _flavorName),
      'BUNDLE_NAME': Variable(value: _flavor.app.name),
      'BUNDLE_DISPLAY_NAME': Variable(value: _flavor.app.name),
    })
      ..addAll(
        _flavor.macos?.variables.where((_, variable) =>
                variable.target == null || variable.target == _target) ??
            {},
      );

    buffer.writeln();
    variables.forEach((key, variable) {
      buffer.writeln('$key=${variable.value}');
    });
  }

  @override
  String toString() => 'MacOSConfigsProcessor';
}
