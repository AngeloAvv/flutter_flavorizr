// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'android.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Android _$AndroidFromJson(Map json) {
  $checkKeys(json,
      requiredKeys: const ['applicationId'],
      disallowNullValues: const ['applicationId']);
  return Android(
    applicationId: json['applicationId'] as String,
    generateDummyAssets: json['generateDummyAssets'] ?? true,
  );
}
