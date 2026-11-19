// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'badge.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FlavorBadge _$FlavorBadgeFromJson(Map json) =>
    $checkedCreate('FlavorBadge', json, ($checkedConvert) {
      $checkKeys(
        json,
        allowedKeys: const ['label', 'color'],
        disallowNullValues: const ['label', 'color'],
      );
      final val = FlavorBadge(
        label: $checkedConvert(
          'label',
          (v) => v == null ? null : _labelFromJson(v as Object),
        ),
        color: $checkedConvert(
          'color',
          (v) => v == null ? null : _colorFromJson(v as Object),
        ),
      );
      return val;
    });
