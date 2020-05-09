// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'flavor.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Flavor _$FlavorFromJson(Map json) {
  $checkKeys(json,
      requiredKeys: const ['app', 'android', 'ios'],
      disallowNullValues: const ['app', 'android', 'ios']);
  return Flavor(
    app: json['app'] == null
        ? null
        : App.fromJson((json['app'] as Map)?.map(
            (k, e) => MapEntry(k as String, e),
          )),
    android: json['android'] == null
        ? null
        : Android.fromJson((json['android'] as Map)?.map(
            (k, e) => MapEntry(k as String, e),
          )),
    ios: json['ios'] == null
        ? null
        : IOS.fromJson((json['ios'] as Map)?.map(
            (k, e) => MapEntry(k as String, e),
          )),
  );
}

Map<String, dynamic> _$FlavorToJson(Flavor instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('app', instance.app);
  writeNotNull('android', instance.android);
  writeNotNull('ios', instance.ios);
  return val;
}
