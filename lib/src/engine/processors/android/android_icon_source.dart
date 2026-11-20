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

import 'package:flutter_flavorizr/src/badge/badge_renderer.dart';
import 'package:flutter_flavorizr/src/badge/resolved_badge.dart';
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
      // the first one is the one decoded. What the entry declares is not what
      // the decoder uses, so the stored image is looked at.
      if (info.images.isEmpty) {
        return false;
      }

      return _storedImageFits(bytes, info.images.first.bytesOffset);
    }

    return info.width > 0 &&
        info.height > 0 &&
        info.width <= maxSide &&
        info.height <= maxSide;
  }

  static const _pngSignature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

  /// Whether the image stored at [offset] of an ICO declares a size within
  /// [maxSide].
  ///
  /// The directory entry says 256 x 256 at most, but the decoder does not use
  /// it: it takes the size from the data itself, which is either a PNG (the
  /// signature, then the IHDR chunk, whose size is at 16) or a DIB (its
  /// BITMAPINFOHEADER, with the width at 4 and the height at 8). The height of
  /// an ICO DIB counts the AND mask too, so the image is half of it.
  static bool _storedImageFits(Uint8List bytes, int offset) {
    const pngHeaderEnd = 24;
    const dibHeaderEnd = 12;

    if (offset < 0 || offset > bytes.length) {
      return false;
    }

    final stored = ByteData.sublistView(bytes, offset);
    final isPng =
        stored.lengthInBytes >= _pngSignature.length &&
        Iterable<int>.generate(
          _pngSignature.length,
        ).every((i) => stored.getUint8(i) == _pngSignature[i]);

    final int width;
    final int height;

    if (isPng) {
      if (stored.lengthInBytes < pngHeaderEnd) {
        return false;
      }

      width = stored.getUint32(16);
      height = stored.getUint32(20);
    } else {
      if (stored.lengthInBytes < dibHeaderEnd) {
        return false;
      }

      width = stored.getInt32(4, Endian.little);
      height = stored.getInt32(8, Endian.little).abs() ~/ 2;
    }

    return width > 0 && height > 0 && width <= maxSide && height <= maxSide;
  }

  /// Renders the icon as a multi-resolution `.ico`: one square frame for each
  /// of [sizes], in that order.
  ///
  /// With a [badge], it is drawn on every frame, at the size of the frame. The
  /// encoder is deterministic, as the one of the PNGs is.
  Uint8List renderIco(Iterable<int> sizes, {ResolvedBadge? badge}) =>
      img.IcoEncoder().encodeImages([
        for (final size in sizes) renderIcon(_image, size, badge: badge),
      ]);

  /// Renders the icon as a PNG of [width] x [height] pixels.
  ///
  /// With a [badge], the icon is a square and the badge is drawn on it, at
  /// that size, in [area].
  Uint8List renderPng(
    int width,
    int height, {
    ResolvedBadge? badge,
    BadgeArea area = BadgeArea.full,
  }) {
    if (badge != null) {
      assert(width == height, 'a badge is drawn on a square icon');

      return img.encodePng(renderIcon(_image, width, badge: badge, area: area));
    }

    return img.encodePng(
      img.copyResize(
        _image,
        width: width,
        height: height,
        interpolation: img.Interpolation.average,
      ),
    );
  }
}
