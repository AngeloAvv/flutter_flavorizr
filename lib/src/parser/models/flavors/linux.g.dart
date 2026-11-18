// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'linux.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Linux _$LinuxFromJson(Map json) =>
    $checkedCreate('Linux', json, ($checkedConvert) {
      $checkKeys(
        json,
        allowedKeys: const ['applicationId'],
        requiredKeys: const ['applicationId'],
        disallowNullValues: const ['applicationId'],
      );
      final val = Linux(
        applicationId: $checkedConvert('applicationId', (v) => v as String),
      );
      return val;
    });
