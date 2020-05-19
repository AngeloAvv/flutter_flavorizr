// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'flavorizr.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Flavorizr _$FlavorizrFromJson(Map json) {
  $checkKeys(json, requiredKeys: const ['app', 'flavors']);
  return Flavorizr(
    app: json['app'] == null
        ? null
        : App.fromJson((json['app'] as Map)?.map(
            (k, e) => MapEntry(k as String, e),
          )),
    flavors: (json['flavors'] as Map)?.map(
      (k, e) => MapEntry(
          k as String,
          e == null
              ? null
              : Flavor.fromJson((e as Map)?.map(
                  (k, e) => MapEntry(k as String, e),
                ))),
    ),
    instructions:
        (json['instructions'] as List)?.map((e) => e as String)?.toList(),
    assetsUrl: json['assetsUrl'] as String ??
        'https://github.com/AngeloAvv/flutter_flavorizr/releases/download/v1.0.2/assets.zip',
  );
}

Map<String, dynamic> _$FlavorizrToJson(Flavorizr instance) => <String, dynamic>{
      'app': instance.app,
      'flavors': instance.flavors,
      'instructions': instance.instructions,
      'assetsUrl': instance.assetsUrl,
    };
