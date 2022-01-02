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

import 'package:flutter_flavorizr/extensions/extensions+map.dart';
import 'package:flutter_flavorizr/parser/models/flavorizr.dart';
import 'package:flutter_flavorizr/parser/models/flavors/flavor.dart';
import 'package:flutter_flavorizr/processors/commons/string_processor.dart';

class IOSFirebaseScriptProcessor extends StringProcessor {
  IOSFirebaseScriptProcessor({
    String? input,
    required Flavorizr config,
  }) : super(
          input: input,
          config: config,
        );

  @override
  String toString() => 'IOSFirebaseScriptProcessor';

  @override
  String execute() {
    StringBuffer buffer = StringBuffer();

    final filteredFlavors = _filteredFlavors(config);
    if (filteredFlavors.isNotEmpty) {
      final iterator = filteredFlavors.keys.iterator;
      iterator.moveNext();

      buffer.writeln('if ${_generateCondition(iterator.current)}');
      buffer.writeln('  ${_generateCopy(iterator.current)}');

      while (iterator.moveNext()) {
        buffer.writeln('elif ${_generateCondition(iterator.current)}');
        buffer.writeln('  ${_generateCopy(iterator.current)}');
      }

      buffer.writeln('fi');
      buffer.writeln();
    }

    return buffer.toString();
  }

  String _generateCondition(String flavorName) =>
      '[ "\$CONFIGURATION" == "Debug-$flavorName" ] || [ "\$CONFIGURATION" == "Release-$flavorName" ]; then';

  String _generateCopy(String flavorName) =>
      'cp Runner/$flavorName/GoogleService-Info.plist Runner/GoogleService-Info.plist';

  Map<String, Flavor> _filteredFlavors(Flavorizr config) => config.flavors
      .where((flavorName, flavor) => flavor.android.firebase != null);
}
