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

import 'package:json_annotation/json_annotation.dart';

import 'android.dart';
import 'app.dart';
import 'darwin.dart';
import 'linux.dart';
import 'windows.dart';

part 'flavor.g.dart';

/// A flavor: its name in the app and the configuration of each platform it is built for. A platform that is `null` is not built for.
@JsonSerializable(
  anyMap: true,
  createToJson: false,
  checked: true,
  disallowUnrecognizedKeys: true,
)
class Flavor {
  /// The app of the flavor.
  @JsonKey(required: true, disallowNullValue: true)
  final App app;

  /// The Android configuration, or `null` when the flavor is not built for Android.
  @JsonKey(required: false, disallowNullValue: true)
  final Android? android;

  /// The iOS configuration, or `null` when the flavor is not built for iOS.
  @JsonKey(required: false, disallowNullValue: true)
  final Darwin? ios;

  /// The macOS configuration, or `null` when the flavor is not built for macOS.
  @JsonKey(required: false, disallowNullValue: true)
  final Darwin? macos;

  /// The Linux configuration, or `null` when the flavor is not built for Linux.
  @JsonKey(required: false, disallowNullValue: true)
  final Linux? linux;

  /// The Windows configuration, or `null` when the flavor is not built for Windows.
  @JsonKey(required: false, disallowNullValue: true)
  final Windows? windows;

  /// Creates a Flavor.
  const Flavor({
    required this.app,
    this.android,
    this.ios,
    this.macos,
    this.linux,
    this.windows,
  });

  /// Reads it from [json], the decoded YAML of the configuration.
  factory Flavor.fromJson(Map json) => _$FlavorFromJson(json);
}
