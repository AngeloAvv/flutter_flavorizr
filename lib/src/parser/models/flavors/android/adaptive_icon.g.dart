// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'adaptive_icon.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AdaptiveIcon _$AdaptiveIconFromJson(Map json) {
  $checkKeys(
    json,
    requiredKeys: const ['foreground', 'background'],
    disallowNullValues: const ['foreground', 'background'],
  );
  return AdaptiveIcon(
    foreground: json['foreground'] as String,
    background: json['background'] as String,
  );
}
