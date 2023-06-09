// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'variable.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Variable _$VariableFromJson(Map json) {
  $checkKeys(
    json,
    requiredKeys: const ['value'],
    disallowNullValues: const ['target', 'value'],
  );
  return Variable(
    value: json['value'] as String,
    target: $enumDecodeNullable(_$TargetEnumMap, json['target']),
  );
}

const _$TargetEnumMap = {
  Target.debug: 'debug',
  Target.profile: 'profile',
  Target.release: 'release',
};
