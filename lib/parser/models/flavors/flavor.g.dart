// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'flavor.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Flavor _$FlavorFromJson(Map json) {
  $checkKeys(
    json,
    requiredKeys: const ['app'],
    disallowNullValues: const ['app', 'android', 'ios'],
  );
  return Flavor(
    app: App.fromJson(Map<String, dynamic>.from(json['app'] as Map)),
    android: json['android'] == null
        ? null
        : Android.fromJson(Map<String, dynamic>.from(json['android'] as Map)),
    ios: json['ios'] == null
        ? null
        : IOS.fromJson(Map<String, dynamic>.from(json['ios'] as Map)),
  );
}
