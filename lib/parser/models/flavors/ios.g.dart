// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ios.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

IOS _$IOSFromJson(Map json) {
  $checkKeys(json,
      requiredKeys: const ['bundleId'], disallowNullValues: const ['bundleId']);
  return IOS(
    bundleId: json['bundleId'] as String,
    generateDummyAssets: json['generateDummyAssets'] ?? true,
  );
}
