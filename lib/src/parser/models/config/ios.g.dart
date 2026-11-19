// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ios.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

IOS _$IOSFromJson(Map json) => $checkedCreate('IOS', json, ($checkedConvert) {
  $checkKeys(
    json,
    allowedKeys: const ['includes', 'buildSettings'],
    disallowNullValues: const ['includes'],
  );
  final val = IOS(
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
