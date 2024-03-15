// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ios.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

IOS _$IOSFromJson(Map json) {
  $checkKeys(
    json,
    disallowNullValues: const ['iOSPListFiles'],
  );
  return IOS(
    buildSettings: (json['buildSettings'] as Map?)?.map(
          (k, e) => MapEntry(k as String, e),
        ) ??
        {},
    iOSPListFiles: (json['iOSPListFiles'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        [],
  );
}
