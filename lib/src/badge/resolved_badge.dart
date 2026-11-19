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

import 'badge_color.dart';
import 'badge_label.dart';
import 'badge_palette.dart';

/// The badge of a flavor, with everything decided: what to write, on which
/// colour, and in which colour the text is.
///
/// It is what the rendering of the icons reads: see
/// `FlavorizrConfig.badgeOf`.
class ResolvedBadge {
  /// The text of the badge, at most 8 characters.
  final String label;

  /// The colour of the band.
  final BadgeColor color;

  /// Creates a badge of a [label], truncated if it is too long, and a [color].
  ResolvedBadge({required String label, required this.color})
    : label = badgeLabel('', label);

  /// The badge of the flavor called [flavorName], with the [label] and the
  /// [color] the configuration sets, if it does: otherwise the upper-cased
  /// name, and the colour that comes from the palette by the name.
  factory ResolvedBadge.of(
    String flavorName, {
    String? label,
    BadgeColor? color,
  }) => ResolvedBadge(
    label: badgeLabel(flavorName, label),
    color: color ?? defaultBadgeColor(flavorName),
  );

  /// The colour of the text, black or white, whichever contrasts more with
  /// [color]: never under 4.5:1.
  BadgeColor get textColor => color.textColor;

  @override
  bool operator ==(Object other) =>
      other is ResolvedBadge && other.label == label && other.color == color;

  @override
  int get hashCode => Object.hash(label, color);

  @override
  String toString() => 'ResolvedBadge($label, $color)';
}
