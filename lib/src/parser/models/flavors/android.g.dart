// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'android.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Android _$AndroidFromJson(Map json) =>
    $checkedCreate('Android', json, ($checkedConvert) {
      $checkKeys(
        json,
        allowedKeys: const [
          'applicationId',
          'customConfig',
          'manifestPlaceholders',
          'resValues',
          'buildConfigFields',
          'agconnect',
          'adaptiveIcon',
          'firebase',
          'icon',
          'generateDummyAssets',
        ],
        requiredKeys: const ['applicationId'],
        disallowNullValues: const [
          'applicationId',
          'customConfig',
          'manifestPlaceholders',
          'resValues',
          'buildConfigFields',
          'agconnect',
          'adaptiveIcon',
          'firebase',
          'icon',
        ],
      );
      final val = Android(
        applicationId: $checkedConvert('applicationId', (v) => v as String),
        customConfig: $checkedConvert(
          'customConfig',
          (v) => (v as Map?)?.map((k, e) => MapEntry(k as String, e)) ?? {},
        ),
        manifestPlaceholders: $checkedConvert(
          'manifestPlaceholders',
          (v) => (v as Map?)?.map((k, e) => MapEntry(k as String, e)) ?? {},
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
        agconnect: $checkedConvert(
          'agconnect',
          (v) => v == null ? null : AGConnect.fromJson(v as Map),
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
        adaptiveIcon: $checkedConvert(
          'adaptiveIcon',
          (v) => v == null ? null : AdaptiveIcon.fromJson(v as Map),
        ),
      );
      return val;
    });
