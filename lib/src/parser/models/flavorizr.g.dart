// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'flavorizr.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Flavorizr _$FlavorizrFromJson(Map json) => $checkedCreate('Flavorizr', json, (
  $checkedConvert,
) {
  $checkKeys(
    json,
    allowedKeys: const ['app', 'flavors', 'assetsUrl', 'ide', 'recipes'],
    requiredKeys: const ['flavors'],
  );
  final val = Flavorizr(
    app: $checkedConvert(
      'app',
      (v) => v == null ? null : App.fromJson(v as Map),
    ),
    flavors: $checkedConvert(
      'flavors',
      (v) => (v as Map).map(
        (k, e) => MapEntry(k as String, Flavor.fromJson(e as Map)),
      ),
    ),
    assetsUrl: $checkedConvert(
      'assetsUrl',
      (v) =>
          v as String? ??
          'https://github.com/AngeloAvv/flutter_flavorizr/releases/download/v2.6.0/assets.zip',
    ),
    ide: $checkedConvert('ide', (v) => _ideListFromJson(v)),
    recipes: $checkedConvert('recipes', (v) => _recipesFromJson(v)),
  );
  return val;
});
