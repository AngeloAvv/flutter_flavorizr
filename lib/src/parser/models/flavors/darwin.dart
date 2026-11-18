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
import 'package:flutter_flavorizr/src/parser/mixins/build_settings_mixin.dart';
import 'package:flutter_flavorizr/src/parser/models/flavors/commons/dummy_assets_mixin.dart';
import 'package:flutter_flavorizr/src/parser/models/flavors/commons/firebase_mixin.dart';
import 'package:flutter_flavorizr/src/parser/models/flavors/commons/icon_mixin.dart';
import 'package:flutter_flavorizr/src/parser/models/flavors/commons/os.dart';
import 'package:flutter_flavorizr/src/parser/models/flavors/darwin/include.dart';
import 'package:flutter_flavorizr/src/parser/models/flavors/darwin/variable.dart';
import 'package:flutter_flavorizr/src/parser/models/flavors/google/firebase/firebase.dart';
import 'package:json_annotation/json_annotation.dart';

part 'darwin.g.dart';

/// The iOS or macOS configuration of a flavor.
@JsonSerializable(
  anyMap: true,
  createToJson: false,
  checked: true,
  disallowUnrecognizedKeys: true,
)
class Darwin extends OS
    with BuildSettingsMixin, FirebaseMixin, IconMixin, DummyAssetsMixin {
  /// The bundle identifier of the flavor.
  @JsonKey(required: true, disallowNullValue: true)
  final String bundleId;

  /// The variables of the xcconfig of the flavor, by name.
  @JsonKey(disallowNullValue: true, defaultValue: {})
  final Map<String, Variable> variables;

  /// The files the xcconfig of the flavor includes.
  @JsonKey(disallowNullValue: true, defaultValue: [])
  final List<Include> includes;

  @override
  @JsonKey(defaultValue: {})
  final Map<String, dynamic> buildSettings;

  @override
  @JsonKey(disallowNullValue: true)
  final Firebase? firebase;

  @override
  @JsonKey(disallowNullValue: true)
  final String? icon;

  @override
  @JsonKey(defaultValue: true)
  final bool generateDummyAssets;

  /// Creates a Darwin.
  Darwin({
    required this.bundleId,
    Map<String, Variable> variables = const {},
    List<Include> includes = const [],
    Map<String, dynamic> buildSettings = const {},
    this.generateDummyAssets = true,
    this.firebase,
    this.icon,
  }) : variables = frozenMap(variables),
       includes = frozenList(includes),
       buildSettings =
           (freeze({'PRODUCT_BUNDLE_IDENTIFIER': bundleId, ...buildSettings})
                   as Map)
               .cast<String, dynamic>();

  /// Reads it from [json], the decoded YAML of the configuration.
  factory Darwin.fromJson(Map json) => _$DarwinFromJson(json);
}
