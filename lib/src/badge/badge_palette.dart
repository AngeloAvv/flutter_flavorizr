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

import 'dart:convert';

import 'badge_color.dart';

/// The colours a badge is picked from when the flavor sets none. Each has a
/// text of at least 4.5:1, either black or white.
///
/// The order is part of the behavior: [defaultBadgeColor] picks by position,
/// so reordering or changing the palette changes the colour of every flavor
/// that does not set one.
final List<BadgeColor> badgePalette = List.unmodifiable(const [
  BadgeColor(0xE5, 0x39, 0x35), // red
  BadgeColor(0xD8, 0x1B, 0x60), // pink
  BadgeColor(0x8E, 0x24, 0xAA), // purple
  BadgeColor(0x5E, 0x35, 0xB1), // deep purple
  BadgeColor(0x39, 0x49, 0xAB), // indigo
  BadgeColor(0x1E, 0x88, 0xE5), // blue
  BadgeColor(0x00, 0x89, 0x7B), // teal
  BadgeColor(0x43, 0xA0, 0x47), // green
  BadgeColor(0xFB, 0x8C, 0x00), // orange
  BadgeColor(0x6D, 0x4C, 0x41), // brown
]);

/// The FNV-1a 32 bit hash of [text] as UTF-8.
///
/// Unlike `String.hashCode`, it is the same in every run, on every machine and
/// in every version of Dart: a colour that comes from it never changes by
/// itself.
int stableHash(String text) {
  var hash = 0x811C9DC5;

  for (final byte in utf8.encode(text)) {
    hash ^= byte;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }

  return hash;
}

/// The colour of the badge of the flavor called [flavorName] when it sets none.
BadgeColor defaultBadgeColor(String flavorName) =>
    badgePalette[stableHash(flavorName) % badgePalette.length];
