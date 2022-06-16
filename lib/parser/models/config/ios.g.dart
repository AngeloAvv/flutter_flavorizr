// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ios.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

IOS _$IOSFromJson(Map json) => IOS(
      buildSettings: (json['buildSettings'] as Map?)?.map(
            (k, e) => MapEntry(k as String, e),
          ) ??
          const {},
      iOSPListFiles: (json['iOSPListFiles'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );
