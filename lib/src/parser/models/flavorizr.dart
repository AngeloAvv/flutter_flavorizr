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

import 'package:checked_yaml/checked_yaml.dart';
import 'package:flutter_flavorizr/src/extensions/extensions_map.dart';
import 'package:flutter_flavorizr/src/parser/flavor_fingerprint.dart';
import 'package:json_annotation/json_annotation.dart';

import 'config/app.dart';
import 'enums.dart';
import 'flavors/flavor.dart';

part 'flavorizr.g.dart';

@JsonSerializable(
  anyMap: true,
  createToJson: false,
  checked: true,
  disallowUnrecognizedKeys: true,
)
class FlavorizrConfig {
  final AppDefaults? app;

  @JsonKey(required: true)
  final Map<String, Flavor> flavors;

  @JsonKey(
    defaultValue:
        'https://github.com/AngeloAvv/flutter_flavorizr/releases/download/v2.6.0/assets.zip',
  )
  final String assetsUrl;

  @JsonKey(fromJson: _ideListFromJson)
  final List<IDE>? ide;

  /// The recipes of the user: names, each with the processor ids and recipes
  /// it contains. A `default` that is a plain name is not a recipe, see
  /// [defaultRecipe].
  @JsonKey(name: 'recipes', fromJson: _recipesFromJson)
  final Map<String, List<String>>? recipes;

  /// The recipe to run when no target is given: the value of `default` in
  /// `recipes` when it is a name.
  @JsonKey(includeFromJson: false)
  String? defaultRecipe;

  /// The fingerprint of the resolved configuration of each flavor, by name. It
  /// is only known to a configuration that was parsed.
  @JsonKey(includeFromJson: false)
  Map<String, String> flavorFingerprints = const {};

  @JsonKey(includeFromJson: false)
  late Map<String, Flavor> androidFlavors;

  @JsonKey(includeFromJson: false)
  late Map<String, Flavor> iosFlavors;

  @JsonKey(includeFromJson: false)
  late Map<String, Flavor> macosFlavors;

  @JsonKey(includeFromJson: false)
  late Map<String, Flavor> linuxFlavors;

  @JsonKey(includeFromJson: false)
  late Map<String, Flavor> windowsFlavors;

  @JsonKey(includeFromJson: false)
  late Map<String, Flavor> androidFirebaseFlavors;

  @JsonKey(includeFromJson: false)
  late Map<String, Flavor> androidAGConnectFlavors;

  @JsonKey(includeFromJson: false)
  late Map<String, Flavor> iosFirebaseFlavors;

  @JsonKey(includeFromJson: false)
  late Map<String, Flavor> macosFirebaseFlavors;

  FlavorizrConfig({
    this.app,
    required this.flavors,
    required this.assetsUrl,
    this.ide,
    this.recipes,
  }) : androidFlavors = flavors.where((_, flavor) => flavor.android != null),
       iosFlavors = flavors.where((_, flavor) => flavor.ios != null),
       macosFlavors = flavors.where((_, flavor) => flavor.macos != null),
       linuxFlavors = flavors.where((_, flavor) => flavor.linux != null),
       windowsFlavors = flavors.where((_, flavor) => flavor.windows != null),
       androidFirebaseFlavors = flavors.where(
         (_, flavor) => flavor.android?.firebase != null,
       ),
       androidAGConnectFlavors = flavors.where(
         (_, flavor) => flavor.android?.agconnect != null,
       ),
       iosFirebaseFlavors = flavors.where(
         (_, flavor) => flavor.ios?.firebase != null,
       ),
       macosFirebaseFlavors = flavors.where(
         (_, flavor) => flavor.macos?.firebase != null,
       );

  factory FlavorizrConfig.fromJson(Map json) => _$FlavorizrConfigFromJson(json)
    ..flavorFingerprints = fingerprintFlavors(json)
    ..defaultRecipe = _defaultRecipeFromJson(json['recipes']);

  factory FlavorizrConfig.parse(String yaml) =>
      checkedYamlDecode(yaml, (o) => FlavorizrConfig.fromJson(o ?? {}));

  bool get androidFlavorsAvailable => androidFlavors.isNotEmpty;

  bool get iosFlavorsAvailable => iosFlavors.isNotEmpty;

  bool get macosFlavorsAvailable => macosFlavors.isNotEmpty;

  bool get linuxFlavorsAvailable => linuxFlavors.isNotEmpty;

  bool get windowsFlavorsAvailable => windowsFlavors.isNotEmpty;

  bool get androidFirebaseFlavorsAvailable => androidFirebaseFlavors.isNotEmpty;

  bool get androidAGConnectFlavorsAvailable =>
      androidAGConnectFlavors.isNotEmpty;

  bool get iosFirebaseFlavorsAvailable => iosFirebaseFlavors.isNotEmpty;

  bool get macosFirebaseFlavorsAvailable => macosFirebaseFlavors.isNotEmpty;
}

List<IDE>? _ideListFromJson(dynamic json) {
  if (json == null) {
    return null;
  }

  final output = switch (json) {
    final List list =>
      list
          .map(
            (e) => IDE.values.firstWhere(
              (ide) => ide.name.toLowerCase() == e.toString().toLowerCase(),
            ),
          )
          .toList(growable: false),
    final String str => [
      IDE.values.firstWhere(
        (ide) => ide.name.toLowerCase() == str.toLowerCase(),
      ),
    ],
    _ => null,
  };

  if (output != null) {
    return output;
  }

  throw FormatException('Invalid format for IDE list');
}

Map<String, List<String>>? _recipesFromJson(dynamic json) {
  if (json == null) {
    return null;
  }

  if (json is! Map) {
    throw FormatException('`recipes` must map recipe names to lists');
  }

  return {
    for (final MapEntry(:key, :value) in json.entries)
      // A `default` that is a name picks a recipe, it is not one.
      if (!(key == 'default' && value is String))
        '$key': switch (value) {
          final List list => [for (final member in list) '$member'],
          _ => throw FormatException(
            'The recipe `$key` must be a list of processors and recipes',
          ),
        },
  };
}

String? _defaultRecipeFromJson(dynamic json) =>
    json is Map && json['default'] is String ? json['default'] as String : null;
