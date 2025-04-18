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

import 'package:flutter_flavorizr/src/extensions/extensions_map.dart';
import 'package:flutter_flavorizr/src/processors/android/icons/android_adaptive_icon_xml_processor.dart';
import 'package:flutter_flavorizr/src/processors/android/icons/android_adaptive_icons_processor.dart';
import 'package:flutter_flavorizr/src/processors/android/icons/android_icon_processor.dart';
import 'package:flutter_flavorizr/src/processors/commons/queue_processor.dart';

class AndroidIconsProcessor extends QueueProcessor {
  AndroidIconsProcessor({
    required super.config,
    required super.logger,
  }) : super(
          [
            ...config.androidFlavors
                .where((_, flavor) =>
                    flavor.app.icon != null || flavor.android?.icon != null)
                .map(
                  (flavorName, flavor) => MapEntry(
                    flavorName,
                    AndroidIconProcessor(
                      flavor.android!.icon ?? flavor.app.icon ?? '',
                      flavorName,
                      config: config,
                      logger: logger,
                    ),
                  ),
                )
                .values,
            ...config.androidFlavors
                .where((_, flavor) => flavor.android!.adaptiveIcon != null)
                .map(
                  (flavorName, flavor) => MapEntry(
                    flavorName,
                    AndroidAdaptiveIconXmlProcessor(
                      flavor.android!.adaptiveIcon!,
                      flavorName,
                      config: config,
                      logger: logger,
                    ),
                  ),
                )
                .values,
            ...config.androidFlavors
                .where((_, flavor) => flavor.android!.adaptiveIcon != null)
                .map(
                  (flavorName, flavor) => MapEntry(
                    flavorName,
                    AndroidAdaptiveIconsProcessor(
                      flavor.android!.adaptiveIcon!.foreground,
                      flavor.android!.adaptiveIcon!.background,
                      flavorName,
                      monochromeSource:
                          flavor.android!.adaptiveIcon!.monochrome,
                      config: config,
                      logger: logger,
                    ),
                  ),
                )
                .values,
          ],
        );

  @override
  String toString() => 'AndroidIconsProcessor';
}
