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

import 'package:flutter_flavorizr/src/parser/models/frozen.dart';
import 'package:flutter_flavorizr/src/parser/models/flavors/android/build_config_field.dart';
import 'package:flutter_flavorizr/src/parser/models/flavors/android/res_value.dart';
import 'package:json_annotation/json_annotation.dart';

part 'android.g.dart';

/// What `app.android` of `flavorizr.yaml` sets for the Android flavors: the `flavorDimensions`, and the `resValues` and `buildConfigFields` that every flavor gets.
@JsonSerializable(
  anyMap: true,
  createToJson: false,
  checked: true,
  disallowUnrecognizedKeys: true,
)
class AndroidDefaults {
  /// The flavor dimension when `flavorDimensions` is not set.
  static const kFlavorDimensionValue = 'flavor-type';

  /// The flavor dimension of the flavors, which Gradle needs.
  @JsonKey(defaultValue: 'flavor-type')
  final String flavorDimensions;

  /// The `resValues` of every flavor, by name.
  @JsonKey(disallowNullValue: true, defaultValue: {})
  final Map<String, ResValue> resValues;

  /// The `buildConfigFields` of every flavor, by name.
  @JsonKey(disallowNullValue: true, defaultValue: {})
  final Map<String, BuildConfigField> buildConfigFields;

  /// Creates a AndroidDefaults.
  AndroidDefaults({
    this.flavorDimensions = kFlavorDimensionValue,
    Map<String, ResValue> resValues = const {},
    Map<String, BuildConfigField> buildConfigFields = const {},
  }) : resValues = frozenMap(resValues),
       buildConfigFields = frozenMap(buildConfigFields);

  /// Reads it from [json], the decoded YAML of the configuration.
  factory AndroidDefaults.fromJson(Map json) => _$AndroidDefaultsFromJson(json);
}
