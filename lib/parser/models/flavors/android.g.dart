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

Map<String, dynamic> _$AndroidToJson(Android instance) {
  final val = <String, dynamic>{
    'generateDummyAssets': instance.generateDummyAssets,
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('applicationId', instance.applicationId);
  return val;
}
