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

import 'package:flutter_flavorizr/processors/commons/string_processor.dart';
import 'package:flutter_flavorizr/processors/ide/vscode/models/configuration.dart';
import 'package:flutter_flavorizr/processors/ide/vscode/models/launch.dart';

class VSCodeLaunchProcessor extends StringProcessor {
  final Iterable<String> _flavorNames;
  static const List<String> modes = ['Debug', 'Profile', 'Release'];

  VSCodeLaunchProcessor(this._flavorNames);

  @override
  execute() => Launch(
        version: '0.2.0',
        configurations: _flavorNames
            .expand(
              (flavorName) => modes.map(
                (mode) => Configuration(
                  name: '$flavorName $mode',
                  flutterMode: mode.toLowerCase(),
                  request: 'launch',
                  type: 'dart',
                  args: [
                    '--flavor',
                    flavorName,
                  ],
                  program: 'lib/main-$flavorName.dart',
                ),
              ),
            )
            .toList(),
      ).toString();

  @override
  String toString() => "VSCodeLaunchProcessor";
}
