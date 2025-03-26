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

import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:flutter_flavorizr/src/parser/models/flavors/flavor.dart';
import 'package:flutter_flavorizr/src/processors/commons/abstract_processor.dart';
import 'package:flutter_flavorizr/src/utils/constants.dart';

import '../commons/copy_file_processor.dart';

class FlutterMainProcessor extends AbstractProcessor {
  final List<AbstractProcessor> _processors;

  FlutterMainProcessor({
    required Flavorizr config,
  })  : _processors = initProcessor(config),
        super(config);

  @override
  void execute() {
    for (final AbstractProcessor processor in _processors) {
      processor.execute();
    }
  }

  @override
  String toString() => 'FlutterMainProcessor';

  static List<AbstractProcessor> initProcessor(Flavorizr config) {
    final List<AbstractProcessor> processors = <AbstractProcessor>[];
    for (final MapEntry<String, Flavor> flavor in config.flavors.entries) {
      processors.add(CopyFileProcessor(
        K.tempFlutterMainPath,
        flavor.value.flutter.entrypoint,
        config: config,
      ));
    }

    return processors;
  }
}
