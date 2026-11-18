// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

App _$AppFromJson(Map json) => $checkedCreate('App', json, ($checkedConvert) {
  $checkKeys(
    json,
    allowedKeys: const ['android', 'ios', 'macos'],
    disallowNullValues: const ['android', 'ios'],
  );
  final val = App(
    android: $checkedConvert(
      'android',
      (v) => v == null ? null : Android.fromJson(v as Map),
    ),
    ios: $checkedConvert(
      'ios',
      (v) => v == null ? null : IOS.fromJson(v as Map),
    ),
    macos: $checkedConvert(
      'macos',
      (v) => v == null ? null : MacOS.fromJson(v as Map),
    ),
  );
  return val;
});
