// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'res_value.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ResValue _$ResValueFromJson(Map json) =>
    $checkedCreate('ResValue', json, ($checkedConvert) {
      $checkKeys(
        json,
        allowedKeys: const ['type', 'value'],
        requiredKeys: const ['type', 'value'],
        disallowNullValues: const ['type', 'value'],
      );
      final val = ResValue(
        type: $checkedConvert('type', (v) => v as String),
        value: $checkedConvert('value', (v) => v as String),
      );
      return val;
    });
