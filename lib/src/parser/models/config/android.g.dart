// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'android.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Android _$AndroidFromJson(Map json) => $checkedCreate('Android', json, (
  $checkedConvert,
) {
  $checkKeys(
    json,
    allowedKeys: const ['flavorDimensions', 'resValues', 'buildConfigFields'],
    disallowNullValues: const ['resValues', 'buildConfigFields'],
  );
  final val = Android(
    flavorDimensions: $checkedConvert(
      'flavorDimensions',
      (v) => v as String? ?? 'flavor-type',
    ),
    resValues: $checkedConvert(
      'resValues',
      (v) =>
          (v as Map?)?.map(
            (k, e) => MapEntry(k as String, ResValue.fromJson(e as Map)),
          ) ??
          {},
    ),
    buildConfigFields: $checkedConvert(
      'buildConfigFields',
      (v) =>
          (v as Map?)?.map(
            (k, e) =>
                MapEntry(k as String, BuildConfigField.fromJson(e as Map)),
          ) ??
          {},
    ),
  );
  return val;
});
