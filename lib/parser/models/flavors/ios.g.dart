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

Map<String, dynamic> _$IOSToJson(IOS instance) {
  final val = <String, dynamic>{
    'generateDummyAssets': instance.generateDummyAssets,
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('bundleId', instance.bundleId);
  return val;
}
