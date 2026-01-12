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

import 'package:flutter_flavorizr/src/models/darwin/icon/darwin_idiom.dart';
import 'package:flutter_flavorizr/src/models/ios/ios_icon.dart';
import 'package:flutter_flavorizr/src/processors/darwin/icons/darwin_icon_target_processor.dart';
import 'package:flutter_flavorizr/src/utils/constants.dart';

class IOSIconTargetProcessor extends DarwinIconTargetProcessor {
  static const _entries = {
    IosIcon(size: 20, idiom: DarwinIdiom.iPhone, scale: 2),
    IosIcon(size: 20, idiom: DarwinIdiom.iPhone, scale: 3),
    IosIcon(size: 29, idiom: DarwinIdiom.iPhone, scale: 1),
    IosIcon(size: 29, idiom: DarwinIdiom.iPhone, scale: 2),
    IosIcon(size: 29, idiom: DarwinIdiom.iPhone, scale: 3),
    IosIcon(size: 40, idiom: DarwinIdiom.iPhone, scale: 2),
    IosIcon(size: 40, idiom: DarwinIdiom.iPhone, scale: 3),
    IosIcon(size: 60, idiom: DarwinIdiom.iPhone, scale: 2),
    IosIcon(size: 60, idiom: DarwinIdiom.iPhone, scale: 3),
    IosIcon(size: 20, idiom: DarwinIdiom.iPad, scale: 1),
    IosIcon(size: 20, idiom: DarwinIdiom.iPad, scale: 2),
    IosIcon(size: 29, idiom: DarwinIdiom.iPad, scale: 1),
    IosIcon(size: 29, idiom: DarwinIdiom.iPad, scale: 2),
    IosIcon(size: 40, idiom: DarwinIdiom.iPad, scale: 1),
    IosIcon(size: 40, idiom: DarwinIdiom.iPad, scale: 2),
    IosIcon(size: 76, idiom: DarwinIdiom.iPad, scale: 1),
    IosIcon(size: 76, idiom: DarwinIdiom.iPad, scale: 2),
    IosIcon(size: 83.5, idiom: DarwinIdiom.iPad, scale: 2),
    IosIcon(size: 1024, idiom: DarwinIdiom.iosMarketing, scale: 1),
  };

  IOSIconTargetProcessor(
    super.source,
    String flavorName, {
    required super.config,
    required super.logger,
  }) : super(
          flavorName: flavorName,
          iconSet: _entries,
          appIconPath: K.iOSAppIconPath,
        );

  @override
  String toString() => 'IOSIconProcessor';
}
