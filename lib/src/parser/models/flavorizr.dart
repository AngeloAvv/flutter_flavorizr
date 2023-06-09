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

import 'package:flutter_flavorizr/src/extensions/extensions_map.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:checked_yaml/checked_yaml.dart';

import 'config/app.dart';
import 'enums.dart';
import 'flavors/flavor.dart';

part 'flavorizr.g.dart';

@JsonSerializable(anyMap: true, createToJson: false)
class Flavorizr {
  final App? app;

  @JsonKey(required: true)
  final Map<String, Flavor> flavors;

  @JsonKey()
  List<String>? instructions;

  @JsonKey(
      defaultValue:
          'https://github.com/AngeloAvv/flutter_flavorizr/releases/download/v2.2.1/assets.zip')
  final String assetsUrl;

  @JsonKey()
  final IDE? ide;

  @JsonKey(includeFromJson: false)
  late Map<String, Flavor> androidFlavors;

  @JsonKey(includeFromJson: false)
  late Map<String, Flavor> iosFlavors;

  @JsonKey(includeFromJson: false)
  late Map<String, Flavor> macosFlavors;

  @JsonKey(includeFromJson: false)
  late Map<String, Flavor> androidFirebaseFlavors;

  @JsonKey(includeFromJson: false)
  late Map<String, Flavor> androidAGConnectFlavors;

  @JsonKey(includeFromJson: false)
  late Map<String, Flavor> iosFirebaseFlavors;

  @JsonKey(includeFromJson: false)
  late Map<String, Flavor> macosFirebaseFlavors;

  Flavorizr({
    this.app,
    required this.flavors,
    this.instructions,
    required this.assetsUrl,
    this.ide,
  })  : androidFlavors = flavors.where((_, flavor) => flavor.android != null),
        iosFlavors = flavors.where((_, flavor) => flavor.ios != null),
        macosFlavors = flavors.where((_, flavor) => flavor.macos != null),
        androidFirebaseFlavors =
            flavors.where((_, flavor) => flavor.android?.firebase != null),
        androidAGConnectFlavors =
            flavors.where((_, flavor) => flavor.android?.agconnect != null),
        iosFirebaseFlavors =
            flavors.where((_, flavor) => flavor.ios?.firebase != null),
        macosFirebaseFlavors =
            flavors.where((_, flavor) => flavor.macos?.firebase != null);


  factory Flavorizr.fromJson(Map json) =>
      _$FlavorizrFromJson(json);

  factory Flavorizr.parse(String yaml) =>
      checkedYamlDecode(yaml, (o) => Flavorizr.fromJson(o ?? {}));

  bool get androidFlavorsAvailable => androidFlavors.isNotEmpty;

  bool get iosFlavorsAvailable => iosFlavors.isNotEmpty;

  bool get macosFlavorsAvailable => macosFlavors.isNotEmpty;

  bool get androidFirebaseFlavorsAvailable => androidFirebaseFlavors.isNotEmpty;

  bool get androidAGConnectFlavorsAvailable =>
      androidAGConnectFlavors.isNotEmpty;

  bool get iosFirebaseFlavorsAvailable => iosFirebaseFlavors.isNotEmpty;

  bool get macosFirebaseFlavorsAvailable => macosFirebaseFlavors.isNotEmpty;
}
