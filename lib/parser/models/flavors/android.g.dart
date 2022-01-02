// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'android.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Android _$AndroidFromJson(Map json) {
  $checkKeys(
    json,
    requiredKeys: const ['applicationId'],
    disallowNullValues: const ['firebase', 'icon', 'applicationId'],
  );
  return Android(
    applicationId: json['applicationId'] as String,
    generateDummyAssets: json['generateDummyAssets'] as bool? ?? true,
    firebase: json['firebase'] == null
        ? null
        : Firebase.fromJson(Map<String, dynamic>.from(json['firebase'] as Map)),
    icon: json['icon'] as String?,
  );
}
