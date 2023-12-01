/*
 * Copyright (c) 2023 Angelo Cassano
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

import 'package:flutter_flavorizr/src/parser/models/flavors/android/adaptive_icon.dart';
import 'package:flutter_flavorizr/src/parser/models/flavors/android/build_config_field.dart';
import 'package:flutter_flavorizr/src/parser/models/flavors/android/res_value.dart';
import 'package:flutter_flavorizr/src/parser/models/flavors/commons/os.dart';
import 'package:flutter_flavorizr/src/parser/models/flavors/google/firebase/firebase.dart';
import 'package:flutter_flavorizr/src/parser/models/flavors/huawei/agconnect/agconnect.dart';
import 'package:json_annotation/json_annotation.dart';

part 'android.g.dart';

@JsonSerializable(anyMap: true, createToJson: false)
class Android extends OS {
  @JsonKey(required: true, disallowNullValue: true)
  final String applicationId;

  @JsonKey(disallowNullValue: true, defaultValue: {})
  final Map<String, dynamic> customConfig;

  @JsonKey(disallowNullValue: true, defaultValue: {})
  final Map<String, ResValue> resValues;

  @JsonKey(disallowNullValue: true, defaultValue: {})
  final Map<String, BuildConfigField> buildConfigFields;

  @JsonKey(disallowNullValue: true)
  final AGConnect? agconnect;

  @JsonKey(disallowNullValue: true)
  final AdaptiveIcon? adaptiveIcon;

  Android({
    required this.applicationId,
    this.customConfig = const {},
    this.resValues = const {},
    this.buildConfigFields = const {},
    this.agconnect,
    bool generateDummyAssets = true,
    Firebase? firebase,
    String? icon,
    this.adaptiveIcon,
  }) : super(
          generateDummyAssets: generateDummyAssets,
          firebase: firebase,
          icon: icon,
        );

  factory Android.fromJson(Map<String, dynamic> json) =>
      _$AndroidFromJson(json);
}
