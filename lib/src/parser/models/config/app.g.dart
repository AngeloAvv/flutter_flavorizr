// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppDefaults _$AppDefaultsFromJson(Map json) =>
    $checkedCreate('AppDefaults', json, ($checkedConvert) {
      $checkKeys(
        json,
        allowedKeys: const ['android', 'ios', 'macos'],
        disallowNullValues: const ['android', 'ios'],
      );
      final val = AppDefaults(
        android: $checkedConvert(
          'android',
          (v) => v == null ? null : AndroidDefaults.fromJson(v as Map),
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
