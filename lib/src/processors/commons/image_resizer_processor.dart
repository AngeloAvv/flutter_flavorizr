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

class ImageResizerProcessor extends CopyFileProcessor {
  final Size size;

  ImageResizerProcessor(
    super.source,
    super.destination,
    this.size, {
    required super.config,
    required super.logger,
  });

  @override
  File execute() {
    logger.detail(
      '[$ImageResizerProcessor] Decoding image from file `$source`',
    );

    final image = decodeImage(File(source).readAsBytesSync());

    if (image == null) {
      logger.detail(
        '[$ImageResizerProcessor] Image from file `$source` does not exist',
        style: logger.theme.err,
      );

      throw FileNotFoundException(source);
    }

    logger.detail(
      '[$ImageResizerProcessor] Image decoded from file `$source`',
      style: logger.theme.success,
    );

    logger.detail(
      '[$ImageResizerProcessor] Resizing image from `$source` with size `$size`',
    );
    final thumbnail = copyResize(
      image,
      width: size.width,
      height: size.height,
      interpolation: Interpolation.average,
    );
    final encodedImage = encodeNamedImage(destination, thumbnail);

    if (encodedImage == null) {
      logger.detail(
        '[$ImageResizerProcessor] Image from file `$source` is malformed',
        style: logger.theme.err,
      );

      throw MalformedResourceException(source);
    }

    logger.detail(
      '[$ImageResizerProcessor] Image resized from `$source` to size `$size`',
      style: logger.theme.success,
    );

    logger.detail(
      '[$ImageResizerProcessor] Writing image to file `$destination`',
    );
    final file = File(destination)
      ..createSync(recursive: true)
      ..writeAsBytesSync(encodedImage);

    logger.detail(
      '[$ImageResizerProcessor] Image written to file `$destination`',
      style: logger.theme.success,
    );

    return file;
  }

  @override
  String toString() =>
      'ImageResizerProcessor {source: $source, destination: $destination, size: $size}';
}

class Size {
  final int width;
  final int height;

  const Size({
    required this.width,
    required this.height,
  });

  @override
  String toString() => 'Size{width: $width, height: $height}';
}
