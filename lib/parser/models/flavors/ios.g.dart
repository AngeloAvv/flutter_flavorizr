// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ios.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

IOS _$IOSFromJson(Map json) {
  $checkKeys(json,
      requiredKeys: const ['bundleId'],
      disallowNullValues: const ['firebase', 'bundleId']);
  return IOS(
    bundleId: json['bundleId'] as String,
    buildSettings: (json['buildSettings'] as Map?)?.map(
          (k, e) => MapEntry(k as String, e),
        ) ??
        {},
    generateDummyAssets: json['generateDummyAssets'] as bool? ?? true,
    firebase: json['firebase'] == null
        ? null
        : Firebase.fromJson(Map<String, dynamic>.from(json['firebase'] as Map)),
  );
}
