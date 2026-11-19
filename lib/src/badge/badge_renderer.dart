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

import 'package:image/image.dart' as img;

import 'badge_color.dart';
import 'resolved_badge.dart';

/// Where on an icon the band of a badge goes.
enum BadgeArea {
  /// The whole icon: the band runs across its bottom, edge to edge. It is what
  /// a legacy launcher icon, an iOS or macOS icon and a Windows one get.
  full,

  /// The safe zone of the foreground layer of an adaptive icon: the circle of
  /// 66 dp at the middle of its 108 dp. A launcher masks the icon with a circle,
  /// a squircle or a teardrop, and crops anything outside that, so the band is
  /// a rectangle that fits in the circle.
  safeZone,
}

/// A rectangle of pixels: [left] and [top] are in it, [right] and [bottom] are
/// the first pixels past it.
class BadgeBand {
  /// The first column of the band.
  final int left;

  /// The first row of the band.
  final int top;

  /// The first column past the band.
  final int right;

  /// The first row past the band.
  final int bottom;

  /// Creates the band of these edges.
  const BadgeBand(this.left, this.top, this.right, this.bottom);

  /// The width in pixels.
  int get width => right - left;

  /// The height in pixels.
  int get height => bottom - top;

  @override
  String toString() => 'BadgeBand($left, $top, $right, $bottom)';
}

/// The sizes, in pixels, of an icon on which the font is used as it is: above
/// this the text is scaled up in proportion, so that the band keeps its look.
///
/// It is the largest an Android icon is rendered, an adaptive foreground at
/// xxxhdpi.
const _nativeFontSize = 432;

/// The height of the band of the whole icon, in proportion to its size.
const _bandHeight = 0.28;

/// The 108 dp canvas of an adaptive icon, and the 66 dp circle that is safe.
const _adaptiveCanvas = 108;
const _adaptiveSafe = 66;

/// The text of a badge as the font draws it.
///
/// `arial48` has the characters of ASCII and no more, so the `…` that cuts a
/// long label is drawn as the three dots it stands for.
String badgeText(String label) => label.replaceAll('…', '...');

/// The band of the badge on an icon of [size] x [size] pixels.
BadgeBand badgeBand(int size, BadgeArea area) {
  switch (area) {
    case BadgeArea.full:
      final height = math.max(3, (size * _bandHeight).round());

      return BadgeBand(0, size - height, size, size);
    case BadgeArea.safeZone:
      final radius = size * _adaptiveSafe / _adaptiveCanvas / 2;
      final center = size / 2;
      // The bottom edge is the narrowest, so it sets the width: the chord of
      // the circle at its distance from the center. The edges are rounded
      // inward, so that no pixel is outside of the circle.
      final bottom = 0.8 * radius;
      final top = 0.3 * radius;
      final half = math.sqrt(radius * radius - bottom * bottom);

      return BadgeBand(
        (center - half).ceil(),
        (center + top).ceil(),
        (center + half).floor(),
        (center + bottom).floor(),
      );
  }
}

/// [icon] with the badge drawn on it, at its size: the band, then the label.
/// [icon] is the one that changes, and is returned.
///
/// The badge is drawn for the size of the icon rather than scaled from a larger
/// one, so that the text of a small icon is as sharp as it can be: the label is
/// drawn with the `arial48` font at the size of the font, then scaled to fit
/// the band, which is down for any icon under 432 px, and up for any above it.
/// Nothing is drawn outside the band.
img.Image drawBadge(
  img.Image icon,
  ResolvedBadge badge, {
  BadgeArea area = BadgeArea.full,
}) {
  final size = math.min(icon.width, icon.height);
  final band = badgeBand(size, area);

  for (var y = band.top; y < band.bottom; y++) {
    for (var x = band.left; x < band.right; x++) {
      _paint(icon, x, y, badge.color);
    }
  }

  final text = _text(badge);

  if (text == null) return icon;

  final marginX = math.max(1, (band.width * 0.06).round());
  final marginY = math.max(1, (band.height * 0.18).round());
  final scale = [
    (band.width - 2 * marginX) / text.width,
    (band.height - 2 * marginY) / text.height,
    math.max(1, size / _nativeFontSize),
  ].reduce(math.min);

  final fitted = scale == 1
      ? text
      : img.copyResize(
          text,
          width: math.max(1, (text.width * scale).round()),
          height: math.max(1, (text.height * scale).round()),
          interpolation: scale < 1
              ? img.Interpolation.average
              : img.Interpolation.cubic,
        );
  final left = band.left + (band.width - fitted.width) ~/ 2;
  final top = band.top + (band.height - fitted.height) ~/ 2;

  for (var y = 0; y < fitted.height; y++) {
    for (var x = 0; x < fitted.width; x++) {
      final pixel = fitted.getPixel(x, y);

      icon.setPixelRgba(
        left + x,
        top + y,
        pixel.r.toInt(),
        pixel.g.toInt(),
        pixel.b.toInt(),
        255,
      );
    }
  }

  return icon;
}

/// The image of the label alone, drawn with the font as it is, on the colour
/// of the band and cropped to the ink: `null` when there is none.
///
/// It is opaque, so that scaling it blends the text with the band and never
/// with a transparent black.
img.Image? _text(ResolvedBadge badge) {
  final font = img.arial48;
  final string = badgeText(badge.label);
  final width = string.codeUnits.fold<int>(
    0,
    (sum, unit) => sum + font.characterXAdvance(String.fromCharCode(unit)),
  );

  if (width <= 0) return null;

  final canvas = img.Image(
    width: width,
    height: font.lineHeight,
    numChannels: 4,
  );
  final background = badge.color;
  final foreground = badge.textColor;

  for (var y = 0; y < canvas.height; y++) {
    for (var x = 0; x < canvas.width; x++) {
      _paint(canvas, x, y, background);
    }
  }

  img.drawString(
    canvas,
    string,
    font: font,
    x: 0,
    y: 0,
    color: img.ColorRgba8(
      foreground.red,
      foreground.green,
      foreground.blue,
      255,
    ),
  );

  var left = canvas.width;
  var top = canvas.height;
  var right = -1;
  var bottom = -1;

  for (var y = 0; y < canvas.height; y++) {
    for (var x = 0; x < canvas.width; x++) {
      final pixel = canvas.getPixel(x, y);

      if (pixel.r != background.red ||
          pixel.g != background.green ||
          pixel.b != background.blue) {
        left = math.min(left, x);
        top = math.min(top, y);
        right = math.max(right, x);
        bottom = math.max(bottom, y);
      }
    }
  }

  if (right < left) return null;

  return img.copyCrop(
    canvas,
    x: left,
    y: top,
    width: right - left + 1,
    height: bottom - top + 1,
  );
}

void _paint(img.Image image, int x, int y, BadgeColor color) =>
    image.setPixelRgba(x, y, color.red, color.green, color.blue, 255);

/// [source] at [size] x [size] pixels, with the badge drawn on it when there
/// is one. The resize is the one of every icon of flavorizr, so a flavor
/// without a badge keeps the icon it always had.
img.Image renderIcon(
  img.Image source,
  int size, {
  ResolvedBadge? badge,
  BadgeArea area = BadgeArea.full,
}) {
  final resized = img.copyResize(
    source,
    width: size,
    height: size,
    interpolation: img.Interpolation.average,
  );

  if (badge == null) return resized;

  // The pixels are written as 8 bit RGBA, whatever the format of the source.
  final rgba =
      resized.format == img.Format.uint8 &&
          resized.numChannels == 4 &&
          !resized.hasPalette
      ? resized
      : resized.convert(format: img.Format.uint8, numChannels: 4);

  return drawBadge(rgba, badge, area: area);
}
