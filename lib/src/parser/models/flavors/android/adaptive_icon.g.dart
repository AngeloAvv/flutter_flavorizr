// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'adaptive_icon.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AdaptiveIcon _$AdaptiveIconFromJson(Map json) =>
    $checkedCreate('AdaptiveIcon', json, ($checkedConvert) {
      $checkKeys(
        json,
        allowedKeys: const ['foreground', 'background', 'monochrome'],
        requiredKeys: const ['foreground', 'background'],
        disallowNullValues: const ['foreground', 'background'],
      );
      final val = AdaptiveIcon(
        foreground: $checkedConvert('foreground', (v) => v as String),
        background: $checkedConvert('background', (v) => v as String),
        monochrome: $checkedConvert('monochrome', (v) => v as String?),
      );
      return val;
    });
