/*
 * Copyright (c) 2022 MyLittleSuite
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

import 'package:flutter_flavorizr/exception/file_not_found_exception.dart';
import 'package:flutter_flavorizr/exception/malformed_resource_exception.dart';
import 'package:flutter_flavorizr/parser/models/flavorizr.dart';
import 'package:flutter_flavorizr/processors/commons/copy_file_processor.dart';
import 'package:image/image.dart';

class ImageResizerProcessor extends CopyFileProcessor {
  final Size size;

  ImageResizerProcessor(
    String source,
    String destination,
    this.size, {
    required Flavorizr config,
  }) : super(
          source,
          destination,
          config: config,
        );

  @override
  File execute() {
    final image = decodeImage(File(source).readAsBytesSync());
    if (image == null) {
      throw FileNotFoundException(source);
    }

    final thumbnail = copyResize(
      image,
      width: size.width,
      height: size.height,
      interpolation: Interpolation.average,
    );
    final encodedImage = encodeNamedImage(thumbnail, destination);

    if (encodedImage == null) {
      throw MalformedResourceException(source);
    }

    return File(destination)..writeAsBytesSync(encodedImage);
  }

  @override
  String toString() =>
      'ImageResizerProcessor: Resizing image to $size from $source to $destination';
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
