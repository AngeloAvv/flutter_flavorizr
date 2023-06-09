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

class IOSIconTargetProcessor extends DarwinIconTargetProcessor {
  static const _entries = {
    'Icon-App-20x20@1x.png': Size(width: 20, height: 20),
    'Icon-App-20x20@2x.png': Size(width: 40, height: 40),
    'Icon-App-20x20@3x.png': Size(width: 60, height: 60),
    'Icon-App-29x29@1x.png': Size(width: 29, height: 29),
    'Icon-App-29x29@2x.png': Size(width: 58, height: 58),
    'Icon-App-29x29@3x.png': Size(width: 87, height: 87),
    'Icon-App-40x40@1x.png': Size(width: 40, height: 40),
    'Icon-App-40x40@2x.png': Size(width: 80, height: 80),
    'Icon-App-40x40@3x.png': Size(width: 120, height: 120),
    'Icon-App-60x60@2x.png': Size(width: 120, height: 120),
    'Icon-App-60x60@3x.png': Size(width: 180, height: 180),
    'Icon-App-76x76@1x.png': Size(width: 76, height: 76),
    'Icon-App-76x76@2x.png': Size(width: 152, height: 152),
    'Icon-App-83.5x83.5@2x.png': Size(width: 167, height: 167),
    'Icon-App-1024x1024@1x.png': Size(width: 1024, height: 1024),
  };

  IOSIconTargetProcessor(
    String source,
    String flavorName, {
    required Flavorizr config,
  }) : super(
          source,
          flavorName: flavorName,
          iconSet: _entries,
          appIconPath: K.iOSAppIconPath,
          config: config,
        );

  @override
  String toString() => 'IOSIconProcessor';
}
