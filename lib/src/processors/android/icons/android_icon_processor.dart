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

import 'package:flutter_flavorizr/src/processors/commons/image_resizer_processor.dart';
import 'package:flutter_flavorizr/src/processors/commons/queue_processor.dart';
import 'package:flutter_flavorizr/src/utils/constants.dart';
import 'package:sprintf/sprintf.dart';

class AndroidIconProcessor extends QueueProcessor {
  static const _entries = {
    'mipmap-mdpi': Size(width: 48, height: 48),
    'mipmap-hdpi': Size(width: 72, height: 72),
    'mipmap-xhdpi': Size(width: 96, height: 96),
    'mipmap-xxhdpi': Size(width: 144, height: 144),
    'mipmap-xxxhdpi': Size(width: 192, height: 192),
  };

  AndroidIconProcessor(
    String source,
    String flavorName, {
    required super.config,
    required super.logger,
  }) : super(
          _entries
              .map(
                (folder, size) => MapEntry(
                  folder,
                  ImageResizerProcessor(
                    source,
                    sprintf(K.androidIconPath, [flavorName, folder]),
                    size,
                    config: config,
                    logger: logger,
                  ),
                ),
              )
              .values,
        );

  @override
  String toString() => 'AndroidIconProcessor';
}
