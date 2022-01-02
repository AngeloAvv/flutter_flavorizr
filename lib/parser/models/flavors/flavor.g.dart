// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'flavor.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Flavor _$FlavorFromJson(Map json) {
  $checkKeys(
    json,
    requiredKeys: const ['app', 'android', 'ios'],
    disallowNullValues: const ['app', 'android', 'ios'],
  );
  return Flavor(
    app: App.fromJson(Map<String, dynamic>.from(json['app'] as Map)),
    android:
        Android.fromJson(Map<String, dynamic>.from(json['android'] as Map)),
    ios: IOS.fromJson(Map<String, dynamic>.from(json['ios'] as Map)),
  );
}
