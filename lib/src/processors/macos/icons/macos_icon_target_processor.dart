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
import 'package:flutter_flavorizr/src/models/macos/macos_icon.dart';
import 'package:flutter_flavorizr/src/processors/darwin/icons/darwin_icon_target_processor.dart';
import 'package:flutter_flavorizr/src/utils/constants.dart';

class MacOSIconTargetProcessor extends DarwinIconTargetProcessor {
  static const _entries = {
    MacosIcon(size: 16, idiom: DarwinIdiom.mac, scale: 1),
    MacosIcon(size: 16, idiom: DarwinIdiom.mac, scale: 2),
    MacosIcon(size: 32, idiom: DarwinIdiom.mac, scale: 1),
    MacosIcon(size: 32, idiom: DarwinIdiom.mac, scale: 2),
    MacosIcon(size: 128, idiom: DarwinIdiom.mac, scale: 1),
    MacosIcon(size: 128, idiom: DarwinIdiom.mac, scale: 2),
    MacosIcon(size: 256, idiom: DarwinIdiom.mac, scale: 1),
    MacosIcon(size: 256, idiom: DarwinIdiom.mac, scale: 2),
    MacosIcon(size: 512, idiom: DarwinIdiom.mac, scale: 1),
    MacosIcon(size: 512, idiom: DarwinIdiom.mac, scale: 2),
  };

  MacOSIconTargetProcessor(
    super.source,
    String flavorName, {
    required super.config,
    required super.logger,
  }) : super(
          flavorName: flavorName,
          iconSet: _entries,
          appIconPath: K.macOSAppIconPath,
        );

  @override
  String toString() => 'MacOSIconProcessor';
}
