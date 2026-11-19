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

import 'dart:math' as math;

import 'package:flutter_flavorizr/src/badge/badge_color.dart';
import 'package:flutter_flavorizr/src/badge/badge_renderer.dart';
import 'package:flutter_flavorizr/src/badge/resolved_badge.dart';
import 'package:image/image.dart' as img;
import 'package:test/test.dart';

final _red = ResolvedBadge(label: 'DEV', color: const BadgeColor(229, 57, 53));
final _yellow = ResolvedBadge(
  label: 'STAGING',
  color: const BadgeColor(255, 235, 59),
);

img.Image _plain(int size) {
  final image = img.Image(width: size, height: size, numChannels: 4);

  return img.fill(image, color: img.ColorRgba8(30, 144, 255, 255));
}

bool _same(img.Image a, img.Image b, int x, int y) {
  final pa = a.getPixel(x, y);
  final pb = b.getPixel(x, y);

  return pa.r == pb.r && pa.g == pb.g && pa.b == pb.b && pa.a == pb.a;
}

/// The pixels the badge changed.
List<(int, int)> _changed(img.Image before, img.Image after) => [
  for (var y = 0; y < before.height; y++)
    for (var x = 0; x < before.width; x++)
      if (!_same(before, after, x, y)) (x, y),
];

void main() {
  group('badgeBand', () {
    test('is a horizontal band across the bottom of the icon', () {
      for (final size in [16, 48, 192, 1024]) {
        final band = badgeBand(size, BadgeArea.full);

        expect(band.left, 0, reason: '$size');
        expect(band.right, size, reason: '$size');
        expect(band.bottom, size, reason: '$size');
        expect(band.top, greaterThan(size ~/ 2), reason: '$size');
        expect(band.height, greaterThanOrEqualTo(size ~/ 5), reason: '$size');
      }
    });

    test('of the safe zone is a rectangle inside the circle of 66 dp', () {
      for (final size in [108, 162, 216, 324, 432]) {
        final band = badgeBand(size, BadgeArea.safeZone);
        final radius = size * 66 / 108 / 2;
        final center = size / 2;

        // Every corner of the rectangle, pixels included, is in the circle.
        for (final (x, y) in [
          (band.left, band.top),
          (band.right, band.top),
          (band.left, band.bottom),
          (band.right, band.bottom),
        ]) {
          final distance = math.sqrt(
            math.pow(x - center, 2) + math.pow(y - center, 2),
          );

          expect(distance, lessThanOrEqualTo(radius), reason: '$size');
        }
        expect(band.width, greaterThan(size ~/ 4), reason: '$size');
        expect(band.height, greaterThan(size ~/ 12), reason: '$size');
      }
    });
  });

  group('drawBadge', () {
    test('paints the band in the colour of the badge and leaves the rest of '
        'the icon alone', () {
      final icon = _plain(192);
      final badged = drawBadge(_plain(192), _red);
      final band = badgeBand(192, BadgeArea.full);

      // The corners of the band carry no text.
      for (final (x, y) in [
        (0, band.top),
        (191, band.top),
        (0, 191),
        (191, 191),
      ]) {
        final pixel = badged.getPixel(x, y);

        expect([pixel.r, pixel.g, pixel.b, pixel.a], [229, 57, 53, 255]);
      }

      for (var y = 0; y < band.top; y++) {
        for (var x = 0; x < 192; x++) {
          expect(_same(icon, badged, x, y), isTrue, reason: '$x,$y');
        }
      }
    });

    test('writes the label in the colour of the text', () {
      final dark = drawBadge(_plain(192), _red);
      final light = drawBadge(_plain(192), _yellow);

      // The text is scaled down, so its edges are blended: what counts is that
      // some pixels are nearer to the colour of the text than to the band.
      bool hasText(img.Image image, BadgeColor band, BadgeColor text) {
        num distance(img.Pixel pixel, BadgeColor color) =>
            (pixel.r - color.red).abs() +
            (pixel.g - color.green).abs() +
            (pixel.b - color.blue).abs();
        final area = badgeBand(192, BadgeArea.full);

        for (var y = area.top; y < area.bottom; y++) {
          for (var x = 0; x < 192; x++) {
            final pixel = image.getPixel(x, y);

            if (distance(pixel, text) < distance(pixel, band)) {
              return true;
            }
          }
        }

        return false;
      }

      expect(hasText(dark, _red.color, _red.textColor), isTrue);
      expect(hasText(light, _yellow.color, _yellow.textColor), isTrue);
    });

    test('keeps the text inside the band, whatever the size and the label', () {
      for (final size in [16, 48, 108, 192, 432, 1024]) {
        for (final label in ['A', 'DEV', 'STAGING', 'ABCDEFG…', 'WWWWWWWW']) {
          final badge = ResolvedBadge(
            label: label,
            color: const BadgeColor(0, 0, 0),
          );
          final icon = _plain(size);
          final badged = drawBadge(_plain(size), badge);
          final band = badgeBand(size, BadgeArea.full);

          for (final (x, y) in _changed(icon, badged)) {
            expect(y, greaterThanOrEqualTo(band.top), reason: '$label $size');
            expect(x >= band.left && x < band.right, isTrue);
          }
        }
      }
    });

    test('draws the dots of an ellipsis, as the font has no glyph for it', () {
      final badge = ResolvedBadge(
        label: 'ABCDEFGHIJ',
        color: const BadgeColor(0, 0, 0),
      );

      expect(badge.label, 'ABCDEFG…');
      expect(badgeText(badge.label), 'ABCDEFG...');
      expect(badgeText('DEV'), 'DEV');

      final dotted = drawBadge(_plain(432), badge);
      final cut = drawBadge(
        _plain(432),
        ResolvedBadge(label: 'ABCDEFG', color: const BadgeColor(0, 0, 0)),
      );

      expect(
        _changed(cut, dotted),
        isNotEmpty,
        reason: 'the dots are there: it is not the picture of the cut label',
      );
    });

    test('is deterministic', () {
      final a = drawBadge(_plain(144), _yellow);
      final b = drawBadge(_plain(144), _yellow);

      expect(a.toUint8List(), b.toUint8List());
    });

    test('in the safe zone touches only pixels of the circle and the '
        'squircle', () {
      for (final size in [108, 162, 216, 324, 432]) {
        for (final badge in [_red, _yellow]) {
          final icon = _plain(size);
          final badged = drawBadge(
            _plain(size),
            badge,
            area: BadgeArea.safeZone,
          );
          final changed = _changed(icon, badged);
          final radius = size * 66 / 108 / 2;
          // The visible area (72 dp) is what a launcher masks with its shape.
          final half = size * 72 / 108 / 2;

          expect(changed, isNotEmpty);

          for (final (x, y) in changed) {
            final dx = x + 0.5 - size / 2;
            final dy = y + 0.5 - size / 2;

            expect(
              math.sqrt(dx * dx + dy * dy),
              lessThanOrEqualTo(radius),
              reason: 'circle $size ${badge.label} $x,$y',
            );
            expect(
              math.pow(dx.abs() / half, 4) + math.pow(dy.abs() / half, 4),
              lessThanOrEqualTo(1),
              reason: 'squircle $size ${badge.label} $x,$y',
            );
          }
        }
      }
    });
  });
}
