// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agconnect.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AGConnect _$AGConnectFromJson(Map json) => $checkedCreate('AGConnect', json, (
  $checkedConvert,
) {
  $checkKeys(
    json,
    allowedKeys: const ['config'],
    requiredKeys: const ['config'],
    disallowNullValues: const ['config'],
  );
  final val = AGConnect(config: $checkedConvert('config', (v) => v as String));
  return val;
});
