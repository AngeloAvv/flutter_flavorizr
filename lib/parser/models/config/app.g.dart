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

Map<String, dynamic> _$AppToJson(App instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('android', instance.android);
  val['ios'] = instance.ios;
  return val;
}
