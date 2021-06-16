// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

App _$AppFromJson(Map json) {
  $checkKeys(json,
      requiredKeys: const ['name'], disallowNullValues: const ['name']);
  return App(
    name: json['name'] as String,
    runner_path: json['runner_path'] as String?,
  );
}
