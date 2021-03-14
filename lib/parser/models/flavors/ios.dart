/*
 * Copyright (c) 2021 MyLittleSuite
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

import 'package:flutter_flavorizr/parser/mixins/build_settings_mixin.dart';
import 'package:flutter_flavorizr/parser/models/flavors/commons/os.dart';
import 'package:json_annotation/json_annotation.dart';

part 'ios.g.dart';

@JsonSerializable(anyMap: true, createToJson: false)
class IOS extends OS with BuildSettingsMixin {
  @JsonKey(required: true, disallowNullValue: true)
  final String bundleId;

  IOS({
    this.bundleId,
    Map<String, dynamic> buildSettings = const {},
    generateDummyAssets,
  }) : super(generateDummyAssets) {
    this.buildSettings = {
      "PRODUCT_BUNDLE_IDENTIFIER": bundleId,
    };
    this.buildSettings.addAll(buildSettings);
  }

  factory IOS.fromJson(Map<String, dynamic> json) => _$IOSFromJson(json);
}
