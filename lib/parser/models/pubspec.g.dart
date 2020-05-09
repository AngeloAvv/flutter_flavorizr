// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pubspec.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Pubspec _$PubspecFromJson(Map json) {
  $checkKeys(json, requiredKeys: const ['flavorizr']);
  return Pubspec(
    flavorizr:
        Flavorizr.fromJson(Map<String, dynamic>.from(json['flavorizr'] as Map)),
  );
}

Map<String, dynamic> _$PubspecToJson(Pubspec instance) => <String, dynamic>{
      'flavorizr': instance.flavorizr,
    };
