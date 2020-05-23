// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

App _$AppFromJson(Map json) {
  $checkKeys(json,
      requiredKeys: const ['android'], disallowNullValues: const ['android']);
  return App(
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
