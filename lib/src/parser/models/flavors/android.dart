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
import 'package:flutter_flavorizr/src/parser/models/flavors/android/adaptive_icon.dart';
import 'package:flutter_flavorizr/src/parser/models/flavors/android/build_config_field.dart';
import 'package:flutter_flavorizr/src/parser/models/flavors/android/res_value.dart';
import 'package:flutter_flavorizr/src/parser/models/flavors/commons/dummy_assets_mixin.dart';
import 'package:flutter_flavorizr/src/parser/models/flavors/commons/firebase_mixin.dart';
import 'package:flutter_flavorizr/src/parser/models/flavors/commons/icon_mixin.dart';
import 'package:flutter_flavorizr/src/parser/models/flavors/commons/os.dart';
import 'package:flutter_flavorizr/src/parser/models/flavors/google/firebase/firebase.dart';
import 'package:flutter_flavorizr/src/parser/models/flavors/huawei/agconnect/agconnect.dart';
import 'package:json_annotation/json_annotation.dart';

part 'android.g.dart';

/// The Android configuration of a flavor.
@JsonSerializable(
  anyMap: true,
  createToJson: false,
  checked: true,
  disallowUnrecognizedKeys: true,
)
class Android extends OS with FirebaseMixin, IconMixin, DummyAssetsMixin {
  /// The application id of the flavor.
  @JsonKey(required: true, disallowNullValue: true)
  final String applicationId;

  /// What goes in the flavor in Gradle, by property: text, numbers, booleans,
  /// lists and maps are written as such, in the language of the script. A map
  /// with the single key `raw` is code that is written as it is.
  @JsonKey(disallowNullValue: true, defaultValue: {})
  final Map<String, dynamic> customConfig;

  /// The `manifestPlaceholders` of the flavor, by name: the same kinds of value
  /// as [customConfig].
  @JsonKey(disallowNullValue: true, defaultValue: {})
  final Map<String, dynamic> manifestPlaceholders;

  /// The `resValues` of the flavor, by name.
  @JsonKey(disallowNullValue: true, defaultValue: {})
  final Map<String, ResValue> resValues;

  /// The `buildConfigFields` of the flavor, by name.
  @JsonKey(disallowNullValue: true, defaultValue: {})
  final Map<String, BuildConfigField> buildConfigFields;

  /// The AppGallery Connect configuration of the flavor.
  @JsonKey(disallowNullValue: true)
  final AGConnect? agconnect;

  /// The adaptive icon of the flavor.
  @JsonKey(disallowNullValue: true)
  final AdaptiveIcon? adaptiveIcon;

  @override
  @JsonKey(disallowNullValue: true)
  final Firebase? firebase;

  @override
  @JsonKey(disallowNullValue: true)
  final String? icon;

  @override
  @JsonKey(defaultValue: true)
  final bool generateDummyAssets;

  /// Creates a Android.
  Android({
    required this.applicationId,
    Map<String, dynamic> customConfig = const {},
    Map<String, dynamic> manifestPlaceholders = const {},
    Map<String, ResValue> resValues = const {},
    Map<String, BuildConfigField> buildConfigFields = const {},
    this.agconnect,
    this.generateDummyAssets = true,
    this.firebase,
    this.icon,
    this.adaptiveIcon,
  }) : customConfig = (freeze(customConfig) as Map).cast<String, dynamic>(),
       manifestPlaceholders = (freeze(manifestPlaceholders) as Map)
           .cast<String, dynamic>(),
       resValues = frozenMap(resValues),
       buildConfigFields = frozenMap(buildConfigFields);

  /// Reads it from [json], the decoded YAML of the configuration.
  factory Android.fromJson(Map json) => _$AndroidFromJson(json);
}
