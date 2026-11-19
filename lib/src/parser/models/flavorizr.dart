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
import 'package:flutter_flavorizr/src/badge/resolved_badge.dart';
import 'package:flutter_flavorizr/src/extensions/extensions_map.dart';
import 'package:flutter_flavorizr/src/parser/config_path.dart';
import 'package:flutter_flavorizr/src/parser/flavor_fingerprint.dart';
import 'package:flutter_flavorizr/src/parser/models/frozen.dart';
import 'package:json_annotation/json_annotation.dart';

import 'config/app.dart';
import 'enums.dart';
import 'flavors/flavor.dart';

part 'flavorizr.g.dart';

/// The configuration of a run: `flavorizr.yaml`, or the `flavorizr` section of `pubspec.yaml`.
///
/// It is read-only: a processor reads it through `FlavorizrContext.config` and cannot change it, nor what it holds (the maps and lists are unmodifiable).
@JsonSerializable(
  anyMap: true,
  createToJson: false,
  checked: true,
  disallowUnrecognizedKeys: true,
)
class FlavorizrConfig {
  /// What `app` sets for the flavors, if anything.
  final AppDefaults? app;

  /// Whether the flavors have a badge on their icon, unless they say otherwise.
  @JsonKey(disallowNullValue: true, defaultValue: false)
  final bool badge;

  /// The path of the icon the badges are drawn on when a flavor has none of its
  /// own, if there is one.
  @JsonKey(disallowNullValue: true)
  final String? icon;

  /// The flavors, by name.
  @JsonKey(required: true)
  final Map<String, Flavor> flavors;

  /// The IDEs to write the run configurations for, if any.
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
  final String? defaultRecipe;

  /// The fingerprint of the resolved configuration of each flavor, by name. It
  /// is only known to a configuration that was parsed.
  @JsonKey(includeFromJson: false)
  final Map<String, String> flavorFingerprints;

  /// The flavors that are built for Android.
  @JsonKey(includeFromJson: false)
  final Map<String, Flavor> androidFlavors;

  /// The flavors that are built for iOS.
  @JsonKey(includeFromJson: false)
  final Map<String, Flavor> iosFlavors;

  /// The flavors that are built for macOS.
  @JsonKey(includeFromJson: false)
  final Map<String, Flavor> macosFlavors;

  /// The flavors that are built for Linux.
  @JsonKey(includeFromJson: false)
  final Map<String, Flavor> linuxFlavors;

  /// The flavors that are built for Windows.
  @JsonKey(includeFromJson: false)
  final Map<String, Flavor> windowsFlavors;

  /// The Android flavors that have a Firebase configuration.
  @JsonKey(includeFromJson: false)
  final Map<String, Flavor> androidFirebaseFlavors;

  /// The Android flavors that have an AppGallery Connect configuration.
  @JsonKey(includeFromJson: false)
  final Map<String, Flavor> androidAGConnectFlavors;

  /// The iOS flavors that have a Firebase configuration.
  @JsonKey(includeFromJson: false)
  final Map<String, Flavor> iosFirebaseFlavors;

  /// The macOS flavors that have a Firebase configuration.
  @JsonKey(includeFromJson: false)
  final Map<String, Flavor> macosFirebaseFlavors;

  /// What the configuration says that is deprecated, as warnings to show: it
  /// still reads, and does nothing, or less than it did.
  @JsonKey(includeFromJson: false)
  final List<String> deprecations;

  /// Creates the configuration of [flavors] and the rest.
  FlavorizrConfig({
    this.app,
    this.badge = false,
    this.icon,
    required Map<String, Flavor> flavors,
    List<IDE>? ide,
    Map<String, List<String>>? recipes,
    this.defaultRecipe,
    Map<String, String> flavorFingerprints = const {},
    List<String> deprecations = const [],
  }) : flavors = frozenMap(flavors),
       deprecations = frozenList(deprecations),
       ide = ide == null ? null : frozenList(ide),
       recipes = recipes == null
           ? null
           : frozenMap({
               for (final entry in recipes.entries)
                 entry.key: frozenList(entry.value),
             }),
       flavorFingerprints = frozenMap(flavorFingerprints),
       androidFlavors = _where(flavors, (flavor) => flavor.android != null),
       iosFlavors = _where(flavors, (flavor) => flavor.ios != null),
       macosFlavors = _where(flavors, (flavor) => flavor.macos != null),
       linuxFlavors = _where(flavors, (flavor) => flavor.linux != null),
       windowsFlavors = _where(flavors, (flavor) => flavor.windows != null),
       androidFirebaseFlavors = _where(
         flavors,
         (flavor) => flavor.android?.firebase != null,
       ),
       androidAGConnectFlavors = _where(
         flavors,
         (flavor) => flavor.android?.agconnect != null,
       ),
       iosFirebaseFlavors = _where(
         flavors,
         (flavor) => flavor.ios?.firebase != null,
       ),
       macosFirebaseFlavors = _where(
         flavors,
         (flavor) => flavor.macos?.firebase != null,
       );

  /// This configuration with [flavors] instead of its own, and everything else
  /// as it is: the root settings, the recipes, the fingerprints.
  ///
  /// Every field of the configuration is carried here, so that a field added to
  /// the constructor is added to this one, and a copy never loses a root
  /// setting.
  FlavorizrConfig withFlavors(Map<String, Flavor> flavors) => FlavorizrConfig(
    app: app,
    badge: badge,
    icon: icon,
    flavors: flavors,
    ide: ide,
    recipes: recipes,
    defaultRecipe: defaultRecipe,
    flavorFingerprints: flavorFingerprints,
    deprecations: deprecations,
  );

  /// The configuration of [json], with what is told from the document as a
  /// whole: the fingerprints of the flavors and the default recipe.
  factory FlavorizrConfig.fromJson(Map json) {
    final parsed = _$FlavorizrConfigFromJson(json);

    return FlavorizrConfig(
      app: parsed.app,
      badge: parsed.badge,
      icon: parsed.icon,
      flavors: parsed.flavors,
      ide: parsed.ide,
      recipes: parsed.recipes,
      defaultRecipe: _defaultRecipeFromJson(json['recipes']),
      flavorFingerprints: fingerprintFlavors(json),
      deprecations: _deprecationsOf(json),
    );
  }

  /// The badge of the flavor called [flavor]: what it says, over what the root
  /// says, and what neither says by default. `null` when the flavor has none,
  /// or is not in the configuration.
  ///
  /// The label is the upper-cased name of the flavor, and the colour comes from
  /// the palette by a stable hash of the name, unless the flavor sets them.
  ResolvedBadge? badgeOf(String flavor) {
    final definition = flavors[flavor];

    if (definition == null) return null;

    final setting = definition.badge;

    if (!(setting?.enabled ?? badge)) return null;

    return ResolvedBadge.of(
      flavor,
      label: setting?.label,
      color: setting?.color,
    );
  }

  /// The platforms of a flavor that had `generateDummyAssets`.
  static const _dummyAssetsPlatforms = ['android', 'ios', 'macos', 'windows'];

  static List<String> _deprecationsOf(Map json) {
    final flavors = json['flavors'];

    if (flavors is! Map) return const [];

    return [
      for (final MapEntry(key: name, value: flavor) in flavors.entries)
        if (flavor is Map)
          for (final platform in _dummyAssetsPlatforms)
            if (flavor[platform] case final Map settings
                when settings.containsKey('generateDummyAssets'))
              '`${joinConfigPath(['flavors', '$name', platform, 'generateDummyAssets'])}` '
                  'is deprecated and ignored: a flavor with no `icon` uses the '
                  'default icon of the project, and the icons that exist are '
                  'left alone. Remove it: it will be an error in 4.0.',
    ];
  }

  static Map<String, Flavor> _where(
    Map<String, Flavor> flavors,
    bool Function(Flavor flavor) test,
  ) => frozenMap(flavors.where((_, flavor) => test(flavor)));

  /// Reads the configuration in [yaml], and fails with what is wrong with it.
  factory FlavorizrConfig.parse(String yaml) =>
      checkedYamlDecode(yaml, (o) => FlavorizrConfig.fromJson(o ?? {}));

  /// Whether any flavor is built for Android.
  bool get androidFlavorsAvailable => androidFlavors.isNotEmpty;

  /// Whether any flavor is built for iOS.
  bool get iosFlavorsAvailable => iosFlavors.isNotEmpty;

  /// Whether any flavor is built for macOS.
  bool get macosFlavorsAvailable => macosFlavors.isNotEmpty;

  /// Whether any flavor is built for Linux.
  bool get linuxFlavorsAvailable => linuxFlavors.isNotEmpty;

  /// Whether any flavor is built for Windows.
  bool get windowsFlavorsAvailable => windowsFlavors.isNotEmpty;

  /// Whether any Android flavor has a Firebase configuration.
  bool get androidFirebaseFlavorsAvailable => androidFirebaseFlavors.isNotEmpty;

  /// Whether any Android flavor has an AppGallery Connect configuration.
  bool get androidAGConnectFlavorsAvailable =>
      androidAGConnectFlavors.isNotEmpty;

  /// Whether any iOS flavor has a Firebase configuration.
  bool get iosFirebaseFlavorsAvailable => iosFirebaseFlavors.isNotEmpty;

  /// Whether any macOS flavor has a Firebase configuration.
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
