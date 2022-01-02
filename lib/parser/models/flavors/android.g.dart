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
      'resValues'
    ],
  );
  return Android(
    applicationId: json['applicationId'] as String,
    resValues: (json['resValues'] as Map?)?.map(
          (k, e) => MapEntry(k as String,
              ResValue.fromJson(Map<String, dynamic>.from(e as Map))),
        ) ??
        {},
    generateDummyAssets: json['generateDummyAssets'] as bool? ?? true,
    firebase: json['firebase'] == null
        ? null
        : Firebase.fromJson(Map<String, dynamic>.from(json['firebase'] as Map)),
    icon: json['icon'] as String?,
  );
}
