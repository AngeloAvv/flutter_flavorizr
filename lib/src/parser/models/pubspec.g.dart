// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pubspec.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Pubspec _$PubspecFromJson(Map json) =>
    $checkedCreate('Pubspec', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['flavorizr']);
      final val = Pubspec(
        flavorizr: $checkedConvert(
          'flavorizr',
          (v) => FlavorizrConfig.fromJson(v as Map),
        ),
      );
      return val;
    });
