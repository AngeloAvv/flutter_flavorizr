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

part 'app.g.dart';

/// The app of a flavor: how it is called, and its icon.
@JsonSerializable(
  anyMap: true,
  createToJson: false,
  checked: true,
  disallowUnrecognizedKeys: true,
)
class App {
  /// The name of the app, which the user sees.
  @JsonKey(required: true, disallowNullValue: true)
  final String name;

  /// The path of the icon of the app, if there is one.
  @JsonKey(disallowNullValue: true)
  final String? icon;

  /// Creates a App.
  const App({required this.name, this.icon});

  /// The name with its quotes escaped, for the files it is written in.
  String get escapedName => name.replaceAll('\'', '\\\'');

  /// Reads it from [json], the decoded YAML of the configuration.
  factory App.fromJson(Map json) => _$AppFromJson(json);
}
