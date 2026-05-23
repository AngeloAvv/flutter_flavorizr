// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'include.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Include _$IncludeFromJson(Map json) {
  $checkKeys(
    json,
    requiredKeys: const ['value'],
    disallowNullValues: const ['target', 'value', 'optional'],
  );
  return Include(
    value: json['value'] as String,
    target: $enumDecodeNullable(_$TargetEnumMap, json['target']),
    optional: json['optional'] as bool? ?? false,
  );
}

const _$TargetEnumMap = {
  Target.debug: 'debug',
  Target.profile: 'profile',
  Target.release: 'release',
};
