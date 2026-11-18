// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'build_config_field.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BuildConfigField _$BuildConfigFieldFromJson(Map json) =>
    $checkedCreate('BuildConfigField', json, ($checkedConvert) {
      $checkKeys(
        json,
        allowedKeys: const ['type', 'value'],
        requiredKeys: const ['type', 'value'],
        disallowNullValues: const ['type', 'value'],
      );
      final val = BuildConfigField(
        type: $checkedConvert('type', (v) => v as String),
        value: $checkedConvert('value', (v) => v as String),
      );
      return val;
    });
