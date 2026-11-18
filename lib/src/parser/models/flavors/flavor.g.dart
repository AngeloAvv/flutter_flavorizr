// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'flavor.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Flavor _$FlavorFromJson(Map json) => $checkedCreate('Flavor', json, (
  $checkedConvert,
) {
  $checkKeys(
    json,
    allowedKeys: const ['app', 'android', 'ios', 'macos', 'linux', 'windows'],
    requiredKeys: const ['app'],
    disallowNullValues: const [
      'app',
      'android',
      'ios',
      'macos',
      'linux',
      'windows',
    ],
  );
  final val = Flavor(
    app: $checkedConvert('app', (v) => App.fromJson(v as Map)),
    android: $checkedConvert(
      'android',
      (v) => v == null ? null : Android.fromJson(v as Map),
    ),
    ios: $checkedConvert(
      'ios',
      (v) => v == null ? null : Darwin.fromJson(v as Map),
    ),
    macos: $checkedConvert(
      'macos',
      (v) => v == null ? null : Darwin.fromJson(v as Map),
    ),
    linux: $checkedConvert(
      'linux',
      (v) => v == null ? null : Linux.fromJson(v as Map),
    ),
    windows: $checkedConvert(
      'windows',
      (v) => v == null ? null : Windows.fromJson(v as Map),
    ),
  );
  return val;
});
