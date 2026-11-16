/*
 * Copyright (c) 2026 Angelo Cassano
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

import 'dart:typed_data';

import 'package:flutter_flavorizr/src/exception/malformed_resource_exception.dart';
import 'package:image/image.dart' as img;

/// A decoded source icon, ready to be rendered at the sizes Android asks for.
///
/// It is the pure part of the icon processors: bytes in, PNG bytes out, no
/// file involved. The resize is the one of 2.x (average interpolation, no
/// aspect ratio kept) and the PNG encoder is deterministic, so the same source
/// always renders the same bytes: re-running a flavorization produces an empty
/// diff.
///
/// The source is user input, so it is bounded before it is decoded: a small
/// file can declare a canvas of billions of pixels (a "decompression bomb").
final class AndroidIconSource {
  /// The largest source file accepted, in bytes.
  static const maxBytes = 32 * 1024 * 1024;

  /// The largest side accepted, in pixels. Android icons are rendered at
  /// 432 x 432 at most. Both sides are bounded, not only their product: a
  /// 16 million x 1 canvas has few pixels yet takes minutes to resize.
  static const maxSide = 4096;

  final img.Image _image;

  const AndroidIconSource._(this._image);

  /// Decodes [bytes], whatever the format `package:image` knows (PNG, JPEG,
  /// ...). Only the first frame of an animated image is used.
  ///
  /// [name] only identifies the source in the error. Throws a
  /// [MalformedResourceException] when [bytes] are not an image, are damaged,
  /// or are bigger than [maxBytes] or have a side longer than [maxSide].
  factory AndroidIconSource.decode(Uint8List bytes, {required String name}) {
    if (bytes.length > maxBytes) {
      throw MalformedResourceException(name);
    }

    try {
      final decoder = img.findDecoderForData(bytes);
      final info = decoder?.startDecode(bytes);

      if (decoder == null ||
          info == null ||
          info.width <= 0 ||
          info.height <= 0 ||
          info.width > maxSide ||
          info.height > maxSide) {
        throw MalformedResourceException(name);
      }

      final image = decoder.decode(bytes, frame: 0);

      if (image == null) {
        throw MalformedResourceException(name);
      }

      return AndroidIconSource._(image);
    } on MalformedResourceException {
      rethrow;
    } on OutOfMemoryError {
      rethrow;
    } catch (_) {
      // The decoders signal damaged data with a variety of errors.
      throw MalformedResourceException(name);
    }
  }

  /// Renders the icon as a PNG of [width] x [height] pixels.
  Uint8List renderPng(int width, int height) => img.encodePng(
    img.copyResize(
      _image,
      width: width,
      height: height,
      interpolation: img.Interpolation.average,
    ),
  );
}
