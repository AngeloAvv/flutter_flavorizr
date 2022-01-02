// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

App _$AppFromJson(Map json) {
  $checkKeys(
    json,
    requiredKeys: const ['android'],
    disallowNullValues: const ['android'],
  );
  return App(
    android:
        Android.fromJson(Map<String, dynamic>.from(json['android'] as Map)),
    ios: json['ios'] == null
        ? null
        : IOS.fromJson(Map<String, dynamic>.from(json['ios'] as Map)),
  );
}
