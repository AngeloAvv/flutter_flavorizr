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

      if (decoder == null || info == null || !_fitsBounds(info, bytes)) {
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

  /// Whether the image that is going to be decoded is within [maxSide], judged
  /// from what the header declares and before decoding it.
  static bool _fitsBounds(img.DecodeInfo info, Uint8List bytes) {
    if (info is img.IcoInfo) {
      // The info of an ICO has no size: the sizes are those of its entries, and
      // the first one is the one decoded. An entry is 256 x 256 at most, but a
      // PNG embedded in it declares a size of its own.
      if (info.images.isEmpty) {
        return false;
      }

      return _embeddedPngFits(bytes, info.images.first.bytesOffset);
    }

    return info.width > 0 &&
        info.height > 0 &&
        info.width <= maxSide &&
        info.height <= maxSide;
  }

  static const _pngSignature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

  /// Whether the PNG at [offset] (the signature, then the IHDR chunk, whose
  /// size is at 16) declares a size within [maxSide]. Data that is not a PNG
  /// (a BMP) is bounded by the 256 pixels of the ICO entry.
  static bool _embeddedPngFits(Uint8List bytes, int offset) {
    const headerEnd = 24;

    if (offset < 0 || offset + _pngSignature.length > bytes.length) {
      return false;
    }

    for (var i = 0; i < _pngSignature.length; i++) {
      if (bytes[offset + i] != _pngSignature[i]) {
        return true;
      }
    }

    if (offset + headerEnd > bytes.length) {
      return false;
    }

    final header = ByteData.sublistView(bytes, offset);
    final width = header.getUint32(16);
    final height = header.getUint32(20);

    return width > 0 && height > 0 && width <= maxSide && height <= maxSide;
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
