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

import 'package:flutter_flavorizr/src/parser/models/flavors/darwin.dart';
import 'package:flutter_flavorizr/src/processors/commons/dummy_assets_processor.dart';
import 'package:flutter_flavorizr/src/processors/commons/queue_processor.dart';

class IOSDummyAssetsProcessor extends QueueProcessor {
  IOSDummyAssetsProcessor(
    String source,
    String destination,
    String flavorName,
    Darwin os, {
    required super.config,
    required super.logger,
  }) : super(
          [
            DummyAssetsProcessor(
              '$source/AppIcon.appiconset',
              '$destination/${flavorName}AppIcon.appiconset',
              os,
              config: config,
              logger: logger,
            ),
            DummyAssetsProcessor(
              '$source/LaunchImage.imageset',
              '$destination/${flavorName}LaunchImage.imageset',
              os,
              config: config,
              logger: logger,
            ),
          ],
        );

  @override
  String toString() => 'IOSDummyAssetsProcessor';
}
