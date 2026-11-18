// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'variable.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Variable _$VariableFromJson(Map json) =>
    $checkedCreate('Variable', json, ($checkedConvert) {
      $checkKeys(
        json,
        allowedKeys: const ['target', 'value'],
        requiredKeys: const ['value'],
        disallowNullValues: const ['target', 'value'],
      );
      final val = Variable(
        value: $checkedConvert('value', (v) => v as String),
        target: $checkedConvert(
          'target',
          (v) => $enumDecodeNullable(_$TargetEnumMap, v),
        ),
      );
      return val;
    });

const _$TargetEnumMap = {
  Target.debug: 'debug',
  Target.profile: 'profile',
  Target.release: 'release',
};
