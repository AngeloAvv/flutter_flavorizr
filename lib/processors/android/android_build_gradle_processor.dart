/*
 * Copyright (c) 2020 MyLittleSuite
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
import 'package:flutter_flavorizr/parser/models/flavorizr.dart';
import 'package:flutter_flavorizr/parser/models/flavors/flavor.dart';
import 'package:flutter_flavorizr/processors/commons/string_processor.dart';

class AndroidBuildGradleProcessor extends StringProcessor {
  static const String androidEntryPoint = 'android {';

  final Flavorizr _flavorizr;

  AndroidBuildGradleProcessor(this._flavorizr, {String input = ''})
      : super(input: input);

  @override
  String execute() {
    int androidPosition = this.input.indexOf(androidEntryPoint);
    if (androidPosition < 0) {
      throw MalformedResourceException(this.input);
    }

    StringBuffer buffer = StringBuffer();

    _appendStartContent(buffer, androidPosition);
    _appendFlavorsDimension(buffer);
    _appendFlavors(buffer);

    _appendEndContent(buffer, androidPosition);

    return buffer.toString();
  }

  void _appendStartContent(StringBuffer buffer, int androidPosition) {
    buffer.writeln(
        this.input.substring(0, androidPosition + androidEntryPoint.length));
  }

  void _appendFlavorsDimension(StringBuffer buffer) {
    buffer.writeln();
    buffer.writeln(
        '    flavorDimensions "${this._flavorizr.app.android.flavorDimensions}"');
    buffer.writeln();
  }

  void _appendFlavors(StringBuffer buffer) {
    buffer.writeln('    productFlavors {');

    this._flavorizr.flavors.forEach((String name, Flavor flavor) {
      buffer.writeln('        $name {');
      buffer.writeln(
          '            dimension "${this._flavorizr.app.android.flavorDimensions}"');
      buffer.writeln(
          '            applicationId "${flavor.android.applicationId}"');
      buffer.writeln(
          '            resValue "string", "app_name", "${flavor.app.name}"');
      buffer.writeln('        }');
    });

    buffer.writeln('    }');
    buffer.writeln();
  }

  void _appendEndContent(StringBuffer buffer, int androidPosition) {
    buffer.writeln(
        this.input.substring(androidPosition + androidEntryPoint.length + 1));
  }

  @override
  String toString() => 'AndroidBuildGradleProcessor';
}
