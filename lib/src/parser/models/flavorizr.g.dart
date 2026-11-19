// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'flavorizr.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FlavorizrConfig _$FlavorizrConfigFromJson(Map json) =>
    $checkedCreate('FlavorizrConfig', json, ($checkedConvert) {
      $checkKeys(
        json,
        allowedKeys: const ['app', 'flavors', 'ide', 'recipes'],
        requiredKeys: const ['flavors'],
      );
      final val = FlavorizrConfig(
        app: $checkedConvert(
          'app',
          (v) => v == null ? null : AppDefaults.fromJson(v as Map),
        ),
        flavors: $checkedConvert(
          'flavors',
          (v) => (v as Map).map(
            (k, e) => MapEntry(k as String, Flavor.fromJson(e as Map)),
          ),
        ),
        ide: $checkedConvert('ide', (v) => _ideListFromJson(v)),
        recipes: $checkedConvert('recipes', (v) => _recipesFromJson(v)),
      );
      return val;
    });
