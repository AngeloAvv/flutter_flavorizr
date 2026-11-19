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
import 'package:json_annotation/json_annotation.dart';

part 'badge.g.dart';

/// What a flavor says about its icon badge: `badge: true`, `badge: false`, or
/// `badge: {label: DEV, color: "#E53935"}`.
///
/// What it leaves out is not decided here: see `FlavorizrConfig.badgeOf`.
@JsonSerializable(
  anyMap: true,
  createToJson: false,
  checked: true,
  disallowUnrecognizedKeys: true,
)
class FlavorBadge {
  /// `badge: true`.
  static const on = FlavorBadge();

  /// `badge: false`.
  static const off = FlavorBadge(enabled: false);

  /// Whether the flavor has a badge, whatever the root says.
  @JsonKey(includeFromJson: false)
  final bool enabled;

  /// The text of the badge, as the configuration wrote it, if it did.
  @JsonKey(disallowNullValue: true, fromJson: _labelFromJson)
  final String? label;

  /// The colour of the badge, if the configuration set it.
  @JsonKey(disallowNullValue: true, fromJson: _colorFromJson)
  final BadgeColor? color;

  /// Creates what a flavor says about its badge.
  const FlavorBadge({this.enabled = true, this.label, this.color});

  /// Reads `true`, `false` or a map of `label` and `color`: [json] is what the
  /// YAML decoded to.
  factory FlavorBadge.fromJson(Object json) => switch (json) {
    true => on,
    false => off,
    final Map map => _$FlavorBadgeFromJson(map),
    _ => throw const FormatException(
      '`badge` must be `true`, `false` or a map of `label` and `color`',
    ),
  };
}

String _labelFromJson(Object json) {
  if (json is! String || json.trim().isEmpty) {
    throw const FormatException('`label` must be a text that is not empty');
  }

  return json;
}

BadgeColor _colorFromJson(Object json) =>
    BadgeColor.parse(json is String ? json : '$json');
