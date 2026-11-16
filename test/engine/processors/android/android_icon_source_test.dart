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

import 'package:flutter_flavorizr/src/engine/processors/android/android_icon_source.dart';
import 'package:flutter_flavorizr/src/exception/malformed_resource_exception.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// A PNG of [width] x [height] with a diagonal gradient, so that resizing it
/// has something to compute.
Uint8List gradientPng(int width, int height) {
  final image = img.Image(width: width, height: height, numChannels: 4);

  for (final pixel in image) {
    pixel
      ..r = pixel.x * 255 ~/ width
      ..g = pixel.y * 255 ~/ height
      ..b = 128
      ..a = 255;
  }

  return img.encodePng(image);
}

void main() {
  group('AndroidIconSource', () {
    test('renders a PNG of the requested size', () {
      final source = AndroidIconSource.decode(
        gradientPng(64, 64),
        name: 'icon.png',
      );

      final rendered = img.decodePng(source.renderPng(48, 48))!;

      expect(rendered.width, 48);
      expect(rendered.height, 48);
    });

    test('renders the same bytes as the 2.x resizer, every time', () {
      final bytes = gradientPng(100, 80);
      final source = AndroidIconSource.decode(bytes, name: 'icon.png');

      final expected = img.encodePng(
        img.copyResize(
          img.decodeImage(bytes)!,
          width: 72,
          height: 72,
          interpolation: img.Interpolation.average,
        ),
      );

      expect(source.renderPng(72, 72), expected);
      expect(source.renderPng(72, 72), expected);
    });

    test('does not alter the source when rendering several sizes', () {
      final source = AndroidIconSource.decode(
        gradientPng(64, 64),
        name: 'icon.png',
      );

      final first = source.renderPng(48, 48);
      source.renderPng(192, 192);

      expect(source.renderPng(48, 48), first);
    });

    test('refuses bytes that are not an image', () {
      expect(
        () => AndroidIconSource.decode(
          Uint8List.fromList([1, 2, 3, 4]),
          name: 'broken.png',
        ),
        throwsA(
          isA<MalformedResourceException>().having(
            (e) => e.content,
            'content',
            'broken.png',
          ),
        ),
      );
    });

    test('refuses a truncated image', () {
      final bytes = gradientPng(64, 64);

      expect(
        () => AndroidIconSource.decode(
          Uint8List.sublistView(bytes, 0, bytes.length ~/ 2),
          name: 'cut.png',
        ),
        throwsA(isA<MalformedResourceException>()),
      );
    });

    test('refuses an image that declares too many pixels, without decoding it '
        '(a tiny file can claim a huge canvas)', () {
      // A 1 x 1 PNG whose IHDR is rewritten to claim 65535 x 65535 pixels.
      final bytes = gradientPng(1, 1);
      final header = ByteData.sublistView(bytes);
      header.setUint32(16, 65535);
      header.setUint32(20, 65535);

      expect(
        () => AndroidIconSource.decode(bytes, name: 'bomb.png'),
        throwsA(isA<MalformedResourceException>()),
      );
    });

    test('refuses a source of a size that cannot be an icon', () {
      expect(
        () => AndroidIconSource.decode(
          Uint8List(AndroidIconSource.maxBytes + 1),
          name: 'huge.png',
        ),
        throwsA(isA<MalformedResourceException>()),
      );
    });
  });
}
