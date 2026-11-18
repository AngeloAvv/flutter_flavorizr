// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'windows.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Windows _$WindowsFromJson(Map json) =>
    $checkedCreate('Windows', json, ($checkedConvert) {
      $checkKeys(
        json,
        allowedKeys: const ['icon', 'generateDummyAssets'],
        disallowNullValues: const ['icon'],
      );
      final val = Windows(
        generateDummyAssets: $checkedConvert(
          'generateDummyAssets',
          (v) => v as bool? ?? true,
        ),
        icon: $checkedConvert('icon', (v) => v as String?),
      );
      return val;
    });
