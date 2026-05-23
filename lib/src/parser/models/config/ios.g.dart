// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ios.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

IOS _$IOSFromJson(Map json) {
  $checkKeys(json, disallowNullValues: const ['includes']);
  return IOS(
    buildSettings:
        (json['buildSettings'] as Map?)?.map(
          (k, e) => MapEntry(k as String, e),
        ) ??
        {},
    includes:
        (json['includes'] as List<dynamic>?)
            ?.map((e) => Include.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList() ??
        [],
  );
}
