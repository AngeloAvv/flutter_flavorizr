// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'darwin.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Darwin _$DarwinFromJson(Map json) =>
    $checkedCreate('Darwin', json, ($checkedConvert) {
      $checkKeys(
        json,
        allowedKeys: const [
          'bundleId',
          'variables',
          'includes',
          'buildSettings',
          'firebase',
          'icon',
          'generateDummyAssets',
        ],
        requiredKeys: const ['bundleId'],
        disallowNullValues: const [
          'bundleId',
          'variables',
          'includes',
          'firebase',
          'icon',
        ],
      );
      final val = Darwin(
        bundleId: $checkedConvert('bundleId', (v) => v as String),
        variables: $checkedConvert(
          'variables',
          (v) =>
              (v as Map?)?.map(
                (k, e) => MapEntry(k as String, Variable.fromJson(e as Map)),
              ) ??
              {},
        ),
        includes: $checkedConvert(
          'includes',
          (v) =>
              (v as List<dynamic>?)
                  ?.map((e) => Include.fromJson(e as Map))
                  .toList() ??
              [],
        ),
        buildSettings: $checkedConvert(
          'buildSettings',
          (v) => (v as Map?)?.map((k, e) => MapEntry(k as String, e)) ?? {},
        ),
        generateDummyAssets: $checkedConvert(
          'generateDummyAssets',
          (v) => v as bool? ?? true,
        ),
        firebase: $checkedConvert(
          'firebase',
          (v) => v == null ? null : Firebase.fromJson(v as Map),
        ),
        icon: $checkedConvert('icon', (v) => v as String?),
      );
      return val;
    });
