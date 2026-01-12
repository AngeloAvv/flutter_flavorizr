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

import 'package:flutter_flavorizr/src/models/darwin/icon/darwin_icon.dart';
import 'package:flutter_flavorizr/src/processors/commons/image_resizer_processor.dart';
import 'package:flutter_flavorizr/src/processors/commons/new_file_string_processor.dart';
import 'package:flutter_flavorizr/src/processors/commons/queue_processor.dart';
import 'package:flutter_flavorizr/src/processors/darwin/icons/darwin_icon_contents_processor.dart';
import 'package:flutter_flavorizr/src/utils/constants.dart';
import 'package:sprintf/sprintf.dart';

abstract class DarwinIconTargetProcessor extends QueueProcessor {
  DarwinIconTargetProcessor(
    String source, {
    required String flavorName,
    required Set<DarwinIcon> iconSet,
    required String appIconPath,
    required super.config,
    required super.logger,
  }) : super(
          [
            NewFileStringProcessor(
              sprintf(
                  appIconPath, [flavorName, K.darwinAppIconContentsFileName]),
              DarwinIconContentsProcessor(
                iconSet,
                config: config,
                logger: logger,
              ),
              config: config,
              logger: logger,
            ),
            ...iconSet.map(
              (icon) => ImageResizerProcessor(
                source,
                sprintf(appIconPath, [flavorName, icon.fileName]),
                icon.imageSize,
                config: config,
                logger: logger,
              ),
            )
          ],
        );

  @override
  String toString() => 'DarwinIconProcessor';
}
