// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'build_config_field.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BuildConfigField _$BuildConfigFieldFromJson(Map json) {
  $checkKeys(
    json,
    requiredKeys: const ['type', 'value'],
    disallowNullValues: const ['type', 'value'],
  );
  return BuildConfigField(
    type: json['type'] as String,
    value: json['value'] as String,
  );
}
