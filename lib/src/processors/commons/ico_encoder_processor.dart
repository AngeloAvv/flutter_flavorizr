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

import 'package:flutter_flavorizr/src/exception/file_not_found_exception.dart';
import 'package:flutter_flavorizr/src/exception/malformed_resource_exception.dart';
import 'package:flutter_flavorizr/src/processors/commons/copy_file_processor.dart';
import 'package:image/image.dart';

/// Packs a source image into a multi-resolution Windows `.ico` file, at the
/// sizes conventionally expected of a Win32 app icon (taskbar, Alt+Tab,
/// shortcut, and Explorer thumbnail).
class IcoEncoderProcessor extends CopyFileProcessor {
  static const List<int> _sizes = [16, 32, 48, 256];

  IcoEncoderProcessor(
    super.source,
    super.destination, {
    required super.config,
    required super.logger,
  });

  @override
  File execute() {
    logger.detail(
      '[$IcoEncoderProcessor] Decoding image from file `$source`',
    );

    if (!file.existsSync()) {
      throw FileNotFoundException(source);
    }

    final image = decodeImage(file.readAsBytesSync());

    if (image == null) {
      logger.detail(
        '[$IcoEncoderProcessor] Image from file `$source` is malformed',
        style: logger.theme.err,
      );

      throw MalformedResourceException(source);
    }

    logger.detail(
      '[$IcoEncoderProcessor] Resizing image from `$source` into ${_sizes.length} sizes',
    );

    final frames = _sizes
        .map(
          (size) => copyResize(
            image,
            width: size,
            height: size,
            interpolation: Interpolation.average,
          ),
        )
        .toList(growable: false);

    final bytes = IcoEncoder().encodeImages(frames);

    final outputFile = File(destination)
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes);

    logger.detail(
      '[$IcoEncoderProcessor] Icon written to file `$destination`',
      style: logger.theme.success,
    );

    return outputFile;
  }

  @override
  String toString() =>
      'IcoEncoderProcessor {source: $source, destination: $destination}';
}
