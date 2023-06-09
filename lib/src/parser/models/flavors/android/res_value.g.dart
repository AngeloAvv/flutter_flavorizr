// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'res_value.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ResValue _$ResValueFromJson(Map json) {
  $checkKeys(
    json,
    requiredKeys: const ['type', 'value'],
    disallowNullValues: const ['type', 'value'],
  );
  return ResValue(
    type: json['type'] as String,
    value: json['value'] as String,
  );
}
