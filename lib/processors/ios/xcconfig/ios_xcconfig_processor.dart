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

import 'package:flutter_flavorizr/processors/commons/string_processor.dart';

class IOSXCConfigProcessor extends StringProcessor {
  final String _appName;
  final String _flavorName;

  IOSXCConfigProcessor(
    this._appName,
    this._flavorName, {
    String? input,
  }) : super(input: input);

  @override
  String execute() {
    StringBuffer buffer = StringBuffer();

    _appendIncludes(buffer);
    _appendBody(buffer);

    return buffer.toString();
  }

  void _appendIncludes(StringBuffer buffer) {
    buffer.writeln('#include "Generated.xcconfig"');
  }

  void _appendBody(StringBuffer buffer) {
    buffer.writeln();
    buffer.writeln('FLUTTER_TARGET=lib/main-$_flavorName.dart');
    buffer.writeln();
    buffer.writeln('ASSET_PREFIX=$_flavorName');
    buffer.writeln('BUNDLE_NAME=$_appName');
  }

  @override
  String toString() => 'IOSXCConfigProcessor';
}
