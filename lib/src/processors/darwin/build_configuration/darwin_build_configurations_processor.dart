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

import 'dart:convert';

import 'package:flutter_flavorizr/src/extensions/extensions_string.dart';
import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:flutter_flavorizr/src/parser/models/flavors/darwin/enums.dart';
import 'package:flutter_flavorizr/src/processors/commons/queue_processor.dart';
import 'package:flutter_flavorizr/src/processors/commons/shell_processor.dart';
import 'package:flutter_flavorizr/src/utils/darwin_utils.dart' as utils;

class DarwinBuildConfigurationsProcessor extends QueueProcessor {
  DarwinBuildConfigurationsProcessor(
    String process,
    String script,
    String project,
    String file,
    String flavorName,
    String bundleId,
    Map<String, dynamic> buildConfigurations, {
    required Flavorizr config,
  }) : super(
          Target.values.map(
            (target) => ShellProcessor(
              process,
              [
                script,
                project,
                utils.flatPath(
                    '$file/$flavorName${target.name.capitalize}.xcconfig'),
                flavorName,
                bundleId,
                target.name.capitalize,
                base64.encode(utf8.encode(jsonEncode(buildConfigurations))),
              ],
              config: config,
            ),
          ),
          config: config,
        );

  @override
  String toString() => 'DarwinBuildConfigurationsProcessor';
}
