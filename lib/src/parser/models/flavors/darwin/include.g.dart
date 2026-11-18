// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'include.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Include _$IncludeFromJson(Map json) =>
    $checkedCreate('Include', json, ($checkedConvert) {
      $checkKeys(
        json,
        allowedKeys: const ['target', 'value', 'optional'],
        requiredKeys: const ['value'],
        disallowNullValues: const ['target', 'value', 'optional'],
      );
      final val = Include(
        value: $checkedConvert('value', (v) => v as String),
        target: $checkedConvert(
          'target',
          (v) => $enumDecodeNullable(_$TargetEnumMap, v),
        ),
        optional: $checkedConvert('optional', (v) => v as bool? ?? false),
      );
      return val;
    });

const _$TargetEnumMap = {
  Target.debug: 'debug',
  Target.profile: 'profile',
  Target.release: 'release',
};
