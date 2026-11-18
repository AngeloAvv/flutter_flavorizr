// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

App _$AppFromJson(Map json) => $checkedCreate('App', json, ($checkedConvert) {
  $checkKeys(
    json,
    allowedKeys: const ['name', 'icon'],
    requiredKeys: const ['name'],
    disallowNullValues: const ['name', 'icon'],
  );
  final val = App(
    name: $checkedConvert('name', (v) => v as String),
    icon: $checkedConvert('icon', (v) => v as String?),
  );
  return val;
});
