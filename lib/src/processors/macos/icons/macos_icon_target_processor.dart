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

import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:flutter_flavorizr/src/processors/commons/image_resizer_processor.dart';
import 'package:flutter_flavorizr/src/processors/darwin/icons/darwin_icon_target_processor.dart';
import 'package:flutter_flavorizr/src/utils/constants.dart';

class MacOSIconTargetProcessor extends DarwinIconTargetProcessor {
  static const _entries = {
    'app_icon_16.png': Size(width: 16, height: 16),
    'app_icon_32.png': Size(width: 32, height: 32),
    'app_icon_64.png': Size(width: 64, height: 64),
    'app_icon_128.png': Size(width: 128, height: 128),
    'app_icon_256.png': Size(width: 256, height: 256),
    'app_icon_512.png': Size(width: 512, height: 512),
    'app_icon_1024.png': Size(width: 1024, height: 1024),
  };

  MacOSIconTargetProcessor(
    String source,
    String flavorName, {
    required Flavorizr config,
  }) : super(
          source,
          flavorName: flavorName,
          iconSet: _entries,
          appIconPath: K.macOSAppIconPath,
          config: config,
        );

  @override
  String toString() => 'MacOSIconProcessor';
}
