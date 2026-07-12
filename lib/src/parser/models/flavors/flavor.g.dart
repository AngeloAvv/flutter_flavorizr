// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'flavor.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Flavor _$FlavorFromJson(Map json) {
  $checkKeys(
    json,
    requiredKeys: const ['app'],
    disallowNullValues: const [
      'app',
      'android',
      'ios',
      'macos',
      'linux',
      'windows',
    ],
  );
  return Flavor(
    app: App.fromJson(Map<String, dynamic>.from(json['app'] as Map)),
    android: json['android'] == null
        ? null
        : Android.fromJson(Map<String, dynamic>.from(json['android'] as Map)),
    ios: json['ios'] == null
        ? null
        : Darwin.fromJson(Map<String, dynamic>.from(json['ios'] as Map)),
    macos: json['macos'] == null
        ? null
        : Darwin.fromJson(Map<String, dynamic>.from(json['macos'] as Map)),
    linux: json['linux'] == null
        ? null
        : Linux.fromJson(Map<String, dynamic>.from(json['linux'] as Map)),
    windows: json['windows'] == null
        ? null
        : Windows.fromJson(Map<String, dynamic>.from(json['windows'] as Map)),
  );
}
