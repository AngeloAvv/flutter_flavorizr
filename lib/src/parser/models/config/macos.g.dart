// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'macos.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MacOS _$MacOSFromJson(Map json) =>
    $checkedCreate('MacOS', json, ($checkedConvert) {
      $checkKeys(
        json,
        allowedKeys: const ['buildSettings', 'includes'],
        disallowNullValues: const ['includes'],
      );
      final val = MacOS(
        buildSettings: $checkedConvert(
          'buildSettings',
          (v) => (v as Map?)?.map((k, e) => MapEntry(k as String, e)) ?? {},
        ),
        includes: $checkedConvert(
          'includes',
          (v) =>
              (v as List<dynamic>?)
                  ?.map((e) => Include.fromJson(e as Map))
                  .toList() ??
              [],
        ),
      );
      return val;
    });
