// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'android.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Android _$AndroidFromJson(Map json) {
  $checkKeys(
    json,
    requiredKeys: const ['applicationId'],
    disallowNullValues: const [
      'firebase',
      'icon',
      'applicationId',
      'customConfig',
      'resValues',
      'buildConfigFields',
      'agconnect'
    ],
  );
  return Android(
    applicationId: json['applicationId'] as String,
    customConfig: (json['customConfig'] as Map?)?.map(
          (k, e) => MapEntry(k as String, e),
        ) ??
        {},
    resValues: (json['resValues'] as Map?)?.map(
          (k, e) => MapEntry(k as String,
              ResValue.fromJson(Map<String, dynamic>.from(e as Map))),
        ) ??
        {},
    buildConfigFields: (json['buildConfigFields'] as Map?)?.map(
          (k, e) => MapEntry(k as String,
              BuildConfigField.fromJson(Map<String, dynamic>.from(e as Map))),
        ) ??
        {},
    agconnect: json['agconnect'] == null
        ? null
        : AGConnect.fromJson(
            Map<String, dynamic>.from(json['agconnect'] as Map)),
    generateDummyAssets: json['generateDummyAssets'] as bool? ?? true,
    firebase: json['firebase'] == null
        ? null
        : Firebase.fromJson(Map<String, dynamic>.from(json['firebase'] as Map)),
    icon: json['icon'] as String?,
    adaptiveIcon: json['adaptiveIcon'] == null
        ? null
        : AdaptiveIcon.fromJson(
            Map<String, dynamic>.from(json['adaptiveIcon'] as Map)),
  );
}
