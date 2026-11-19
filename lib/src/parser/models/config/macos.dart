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
import 'package:flutter_flavorizr/src/parser/models/flavors/darwin/include.dart';
import 'package:json_annotation/json_annotation.dart';

part 'macos.g.dart';

/// What `app.macos` of `flavorizr.yaml` sets for the macOS flavors.
@JsonSerializable(
  anyMap: true,
  createToJson: false,
  checked: true,
  disallowUnrecognizedKeys: true,
)
class MacOS with BuildSettingsMixin {
  /// The files every macOS xcconfig includes.
  @JsonKey(disallowNullValue: true, defaultValue: [])
  final List<Include> includes;

  @override
  @JsonKey(defaultValue: {})
  final Map<String, dynamic> buildSettings;

  /// The build settings the configuration wrote, without the defaults that
  /// [buildSettings] starts from: what the user chose.
  @JsonKey(includeFromJson: false, includeToJson: false)
  final Map<String, dynamic> userBuildSettings;

  /// Creates a MacOS.
  MacOS({
    Map<String, dynamic> buildSettings = const {},
    List<Include> includes = const [],
  }) : includes = frozenList(includes),
       userBuildSettings = (freeze(buildSettings) as Map).cast<String, dynamic>(),
       buildSettings =
           (freeze({
                     ...BuildSettingsMixin.macosDefaultBuildSettings,
                     ...buildSettings,
                   })
                   as Map)
               .cast<String, dynamic>();

  /// Reads it from [json], the decoded YAML of the configuration.
  factory MacOS.fromJson(Map json) => _$MacOSFromJson(json);
}
