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

import 'package:flutter_flavorizr/src/exception/malformed_resource_exception.dart';
import 'package:flutter_flavorizr/src/extensions/extensions_string.dart';
import 'package:flutter_flavorizr/src/parser/models/flavors/darwin/enums.dart';
import 'package:flutter_flavorizr/src/processors/commons/string_processor.dart';

class PodfileProcessor extends StringProcessor {
  static const projectEntryPoint = 'project \'Runner\', {';
  static const projectClosure = '}';

  final List<String> flavors;

  PodfileProcessor({
    super.input,
    required this.flavors,
    required super.config,
    required super.logger,
  });

  @override
  String execute() {
    logger.detail(
      '[$PodfileProcessor] Updating Podfile to add flavors',
    );

    final projectPosition = input!.indexOf(projectEntryPoint);
    final closedProjectPosition = input!.indexOf(projectClosure);

    if (projectPosition < 0) {
      logger.detail(
        '[$PodfileProcessor] Podfile does not contain the project entry point',
        style: logger.theme.err,
      );

      throw MalformedResourceException(input!);
    }

    logger.detail(
      '[$PodfileProcessor] Podfile project entry point found',
    );

    final buffer = StringBuffer();

    logger.detail('[$PodfileProcessor] Appending flavors to Podfile');
    _appendStartContent(buffer, projectPosition);
    _appendFlavors(buffer);

    _appendEndContent(buffer, closedProjectPosition);

    logger.detail(
      '[$PodfileProcessor] Podfile updated successfully',
      style: logger.theme.success,
    );

    return buffer.toString();
  }

  void _appendStartContent(StringBuffer buffer, int position) {
    buffer.writeln(input!.substring(0, position + projectEntryPoint.length));
  }

  void _appendFlavors(StringBuffer buffer) {
    for (final flavor in flavors) {
      for (final target in Target.values) {
        buffer.writeln(
            '  \'${target.name.capitalize}-$flavor\' => :${target.darwinTarget},');
      }
    }
  }

  void _appendEndContent(StringBuffer buffer, int position) {
    buffer.write(input!.substring(position));
  }

  @override
  String toString() => 'PodfileProcessor';
}
