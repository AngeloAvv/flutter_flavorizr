// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'macos.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MacOS _$MacOSFromJson(Map json) {
  $checkKeys(json, disallowNullValues: const ['includes']);
  return MacOS(
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
