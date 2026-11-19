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

import 'package:flutter_flavorizr/src/badge/badge_color.dart';
import 'package:flutter_flavorizr/src/badge/badge_palette.dart';
import 'package:test/test.dart';

void main() {
  group('BadgeColor', () {
    test('reads #RRGGBB and #RGB, in any case', () {
      expect(BadgeColor.parse('#E53935'), const BadgeColor(0xE5, 0x39, 0x35));
      expect(BadgeColor.parse('#e53935'), BadgeColor.parse('#E53935'));
      expect(BadgeColor.parse('#fa0'), const BadgeColor(0xFF, 0xAA, 0x00));
    });

    test('refuses what is not a hex colour', () {
      for (final text in [
        'E53935',
        '#E5393',
        '#GGGGGG',
        'red',
        '',
        '#12345678',
      ]) {
        expect(
          () => BadgeColor.parse(text),
          throwsFormatException,
          reason: text,
        );
      }
    });

    test('writes itself as upper-case #RRGGBB', () {
      expect(const BadgeColor(0xE5, 0x39, 0x05).hex, '#E53905');
    });

    test('has the contrast of the WCAG definition', () {
      const black = BadgeColor(0, 0, 0);
      const white = BadgeColor(255, 255, 255);

      expect(black.contrastWith(white), closeTo(21, 1e-9));
      expect(white.contrastWith(black), closeTo(21, 1e-9));
      expect(white.contrastWith(white), closeTo(1, 1e-9));
      // The ratio of #777777 on white is the well-known 4.48.
      expect(
        const BadgeColor(0x77, 0x77, 0x77).contrastWith(white),
        closeTo(4.48, 0.01),
      );
    });

    test('has black text on a light colour and white text on a dark one', () {
      expect(BadgeColor.parse('#FFEB3B').textColor, BadgeColor.black);
      expect(BadgeColor.parse('#FFFFFF').textColor, BadgeColor.black);
      expect(BadgeColor.parse('#000000').textColor, BadgeColor.white);
      expect(BadgeColor.parse('#3949AB').textColor, BadgeColor.white);
    });

    test('has a text of at least 4.5:1 on any colour', () {
      for (var red = 0; red < 256; red += 17) {
        for (var green = 0; green < 256; green += 17) {
          for (var blue = 0; blue < 256; blue += 17) {
            final color = BadgeColor(red, green, blue);

            expect(
              color.contrastWith(color.textColor),
              greaterThanOrEqualTo(4.5),
              reason: color.hex,
            );
          }
        }
      }
    });
  });

  group('the palette', () {
    test('has a text of at least 4.5:1 for every colour', () {
      for (final color in badgePalette) {
        expect(
          color.contrastWith(color.textColor),
          greaterThanOrEqualTo(4.5),
          reason: color.hex,
        );
      }
    });

    test('has no colour twice', () {
      expect(badgePalette.toSet(), hasLength(badgePalette.length));
    });

    test('is unmodifiable', () {
      expect(() => badgePalette.add(BadgeColor.black), throwsUnsupportedError);
    });
  });

  group('stableHash', () {
    test('is FNV-1a 32 bit of the UTF-8 text', () {
      // Known values of the algorithm, from its reference implementation.
      expect(stableHash(''), 2166136261);
      expect(stableHash('a'), 3826002220);
      expect(stableHash('dev'), 3579418556);
      expect(stableHash('staging'), 2597808422);
      expect(stableHash('prod'), 3980276084);
    });

    test('reads the text as UTF-8', () {
      expect(stableHash('é'), 513665217);
    });
  });

  group('defaultBadgeColor', () {
    test('is always the same for a flavor name', () {
      expect(defaultBadgeColor('dev'), BadgeColor.parse('#00897B'));
      expect(defaultBadgeColor('staging'), BadgeColor.parse('#8E24AA'));
      expect(defaultBadgeColor('prod'), BadgeColor.parse('#3949AB'));
      expect(defaultBadgeColor('a'), BadgeColor.parse('#E53935'));
      expect(defaultBadgeColor(''), BadgeColor.parse('#D81B60'));
    });

    test('is a colour of the palette', () {
      for (final name in ['apple', 'banana', 'qa', 'Flavor 1', 'ünï']) {
        expect(badgePalette, contains(defaultBadgeColor(name)));
      }
    });
  });
}
