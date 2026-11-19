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

/// An opaque sRGB colour of a badge.
class BadgeColor {
  /// Black, the text on a light badge.
  static const black = BadgeColor(0, 0, 0);

  /// White, the text on a dark badge.
  static const white = BadgeColor(255, 255, 255);

  /// The red channel, 0 to 255.
  final int red;

  /// The green channel, 0 to 255.
  final int green;

  /// The blue channel, 0 to 255.
  final int blue;

  /// Creates a colour of its channels, each from 0 to 255.
  const BadgeColor(this.red, this.green, this.blue)
    : assert(red >= 0 && red <= 255),
      assert(green >= 0 && green <= 255),
      assert(blue >= 0 && blue <= 255);

  static final _hex = RegExp(r'^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$');

  /// Reads `#RRGGBB` or `#RGB`, in any case. Fails with a [FormatException]
  /// on anything else.
  factory BadgeColor.parse(String text) {
    final match = _hex.firstMatch(text);

    if (match == null) {
      throw FormatException(
        '`$text` is not a colour: write it as `#RRGGBB`, such as `#E53935`',
      );
    }

    var digits = match.group(1)!;

    if (digits.length == 3) {
      digits = [for (final digit in digits.split('')) '$digit$digit'].join();
    }

    final value = int.parse(digits, radix: 16);

    return BadgeColor((value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF);
  }

  /// The colour as `#RRGGBB`, in upper case.
  String get hex =>
      '#${[red, green, blue].map((c) => c.toRadixString(16).padLeft(2, '0')).join().toUpperCase()}';

  /// The colour as a 24 bit integer, `0xRRGGBB`.
  int get value => (red << 16) | (green << 8) | blue;

  /// The relative luminance of the WCAG 2.x definition, from 0 to 1.
  double get luminance {
    double linear(int channel) {
      final c = channel / 255;

      return c <= 0.03928
          ? c / 12.92
          : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
    }

    return 0.2126 * linear(red) +
        0.7152 * linear(green) +
        0.0722 * linear(blue);
  }

  /// The contrast ratio of the WCAG 2.x definition between this colour and
  /// [other], from 1 to 21. It does not depend on which is on top.
  double contrastWith(BadgeColor other) {
    final a = luminance;
    final b = other.luminance;

    return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);
  }

  /// The colour of a text on this one, [black] or [white]: whichever contrasts
  /// more. It is never under 4.5:1, the ratio WCAG asks of a text.
  BadgeColor get textColor =>
      contrastWith(white) >= contrastWith(black) ? white : black;

  @override
  bool operator ==(Object other) => other is BadgeColor && other.value == value;

  @override
  int get hashCode => value;

  @override
  String toString() => hex;
}
