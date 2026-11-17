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

import 'dart:collection';

import 'package:flutter_flavorizr/src/extensions/extensions_string.dart';
import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:flutter_flavorizr/src/parser/models/flavors/darwin/enums.dart';
import 'package:flutter_flavorizr/src/parser/models/flavors/darwin/include.dart';
import 'package:flutter_flavorizr/src/parser/models/flavors/darwin/variable.dart';
import 'package:flutter_flavorizr/src/parser/models/flavors/flavor.dart';

/// The name of the xcconfig of [flavorName] for [target], e.g.
/// `appleDebug.xcconfig`.
String xcconfigName(String flavorName, Target target) =>
    '$flavorName${target.name.capitalize}.xcconfig';

/// The text of `ios/Flutter/<flavor><Target>.xcconfig`.
///
/// It includes the Pods xcconfig **optionally** (`#include?`): the file does
/// not exist until `pod install` ran, and a plain `#include` would break the
/// build. Then the Flutter generated one, the includes of the app and of the
/// flavor that apply to [target], and last the variables.
///
/// It is plain text, written as it is: reading it with an xcconfig parser and
/// writing it back would turn `#include?` into `#include`, sort the keys and
/// drop whatever is not a setting.
String iosXcconfigSource(
  Flavorizr config,
  String flavorName,
  Flavor flavor,
  Target target,
) {
  final buffer = StringBuffer();

  _writeIncludes(
    buffer,
    target,
    generated: 'Generated.xcconfig',
    includes: [...?config.app?.ios?.includes, ...?flavor.ios?.includes],
  );
  _writeVariables(buffer, flavorName, flavor, target, flavor.ios?.variables);

  return buffer.toString();
}

/// The text of `macos/Flutter/<flavor><Target>.xcconfig`: the same as the one
/// of iOS, without variables, which `Runner/Configs` holds on macOS (see
/// [macosConfigsXcconfigSource]).
String macosFlutterXcconfigSource(
  Flavorizr config,
  String flavorName,
  Flavor flavor,
  Target target,
) {
  final buffer = StringBuffer();

  _writeIncludes(
    buffer,
    target,
    generated: 'ephemeral/Flutter-Generated.xcconfig',
    includes: [...?config.app?.macos?.includes, ...?flavor.macos?.includes],
  );

  return buffer.toString();
}

/// The text of `macos/Runner/Configs/<flavor><Target>.xcconfig`: the one of
/// Flutter and the warnings, then the variables.
String macosConfigsXcconfigSource(
  Flavorizr config,
  String flavorName,
  Flavor flavor,
  Target target,
) {
  final buffer = StringBuffer()
    ..writeln('#include "../../Flutter/${xcconfigName(flavorName, target)}"')
    ..writeln('#include "Warnings.xcconfig"');

  _writeVariables(buffer, flavorName, flavor, target, flavor.macos?.variables);

  return buffer.toString();
}

void _writeIncludes(
  StringBuffer buffer,
  Target target, {
  required String generated,
  required List<Include> includes,
}) {
  buffer
    ..writeln(
      '#include? "Pods/Target Support Files/Pods-Runner/'
      'Pods-Runner.${target.darwinTarget}.xcconfig"',
    )
    ..writeln('#include "$generated"');

  for (final include in includes) {
    if (include.target == null || include.target == target) {
      buffer.writeln(
        '${include.optional ? '#include?' : '#include'} "${include.value}"',
      );
    }
  }
}

void _writeVariables(
  StringBuffer buffer,
  String flavorName,
  Flavor flavor,
  Target target,
  Map<String, Variable>? flavorVariables,
) {
  final variables = LinkedHashMap<String, Variable>.from({
    'ASSET_PREFIX': Variable(value: flavorName),
    'BUNDLE_NAME': Variable(value: flavor.app.name),
    'BUNDLE_DISPLAY_NAME': Variable(value: flavor.app.name),
  });

  for (final MapEntry(:key, :value) in flavorVariables?.entries ?? const {}) {
    if (value.target == null || value.target == target) {
      variables[key] = value;
    }
  }

  buffer.writeln();
  for (final MapEntry(:key, :value) in variables.entries) {
    buffer.writeln('$key=${value.value}');
  }
}
