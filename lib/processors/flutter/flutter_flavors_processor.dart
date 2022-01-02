/*
 * Copyright (c) 2022 MyLittleSuite
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

import 'package:flutter_flavorizr/parser/models/flavorizr.dart';
import 'package:flutter_flavorizr/parser/models/flavors/flavor.dart';
import 'package:flutter_flavorizr/processors/commons/string_processor.dart';

class FlutterFlavorsProcessor extends StringProcessor {
  FlutterFlavorsProcessor({
    String? input,
    required Flavorizr config,
  }) : super(
          input: input,
          config: config,
        );

  @override
  String execute() {
    StringBuffer buffer = StringBuffer();

    _appendFlavorEnum(buffer);
    _appendFlavorClass(buffer);

    return buffer.toString();
  }

  void _appendFlavorEnum(StringBuffer buffer) {
    buffer.writeln('enum Flavor {');

    config.flavors.keys.forEach((String flavorName) {
      buffer.writeln('  ${flavorName.toUpperCase()},');
    });

    buffer.writeln('}');
  }

  void _appendFlavorClass(StringBuffer buffer) {
    buffer.writeln();
    buffer.writeln('class F {');
    buffer.writeln('  static Flavor? appFlavor;');
    buffer.writeln();

    buffer.writeln('  static String get name => appFlavor?.name ?? \'\';');
    buffer.writeln();

    buffer.writeln('  static String get title {');
    buffer.writeln('    switch (appFlavor) {');

    config.flavors.forEach((String name, Flavor flavor) {
      buffer.writeln('      case Flavor.${name.toUpperCase()}:');
      buffer.writeln('        return \'${flavor.app.name}\';');
    });

    buffer.writeln('      default:');
    buffer.writeln('        return \'title\';');
    buffer.writeln('    }');
    buffer.writeln('  }');

    buffer.writeln();
    buffer.writeln('}');
  }

  @override
  String toString() => 'FlutterFlavorsProcessor';
}
