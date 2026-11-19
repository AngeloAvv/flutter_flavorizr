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

import 'dart:io';

import 'package:flutter_flavorizr/src/processors/commons/copy_folder_processor.dart';
import 'package:flutter_flavorizr/src/processors/commons/queue_processor.dart';

/// Copies the `LaunchImage.imageset` that the launch screen of a flavor uses,
/// unless the project has one for the flavor already (it has a
/// `Contents.json`).
///
/// It used to copy a dummy `AppIcon-<flavor>.appiconset` too, which it does not
/// anymore: a flavor with no `icon` builds with the `AppIcon` of the project
/// (see `DarwinIconName`), and an appiconset that exists is the user's.
class IOSDummyAssetsProcessor extends QueueProcessor {
  IOSDummyAssetsProcessor(
    String source,
    String destination,
    String flavorName, {
    required super.config,
    required super.logger,
  }) : super([
         // A launch image that is in the project is the user's: it is not
         // replaced by the placeholder.
         if (!File(
           '$destination/${flavorName}LaunchImage.imageset/Contents.json',
         ).existsSync())
           CopyFolderProcessor(
             '$source/LaunchImage.imageset',
             '$destination/${flavorName}LaunchImage.imageset',
             config: config,
             logger: logger,
           ),
       ]);

  @override
  String toString() => 'IOSDummyAssetsProcessor';
}
