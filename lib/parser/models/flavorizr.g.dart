// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'flavorizr.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Flavorizr _$FlavorizrFromJson(Map json) {
  $checkKeys(json, requiredKeys: const ['app', 'flavors']);
  return Flavorizr(
    app: App.fromJson(Map<String, dynamic>.from(json['app'] as Map)),
    flavors: (json['flavors'] as Map).map(
      (k, e) => MapEntry(
          k as String, Flavor.fromJson(Map<String, dynamic>.from(e as Map))),
    ),
    instructions: (json['instructions'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    assetsUrl: json['assetsUrl'] as String? ??
        'https://github.com/AngeloAvv/flutter_flavorizr/releases/download/v2.0.0/assets.zip',
    ide: _$enumDecodeNullable(_$IDEEnumMap, json['ide']),
  );
}

K _$enumDecode<K, V>(
  Map<K, V> enumValues,
  Object? source, {
  K? unknownValue,
}) {
  if (source == null) {
    throw ArgumentError(
      'A value must be provided. Supported values: '
      '${enumValues.values.join(', ')}',
    );
  }

  return enumValues.entries.singleWhere(
    (e) => e.value == source,
    orElse: () {
      if (unknownValue == null) {
        throw ArgumentError(
          '`$source` is not one of the supported values: '
          '${enumValues.values.join(', ')}',
        );
      }
      return MapEntry(unknownValue, enumValues.values.first);
    },
  ).key;
}

K? _$enumDecodeNullable<K, V>(
  Map<K, V> enumValues,
  dynamic source, {
  K? unknownValue,
}) {
  if (source == null) {
    return null;
  }
  return _$enumDecode<K, V>(enumValues, source, unknownValue: unknownValue);
}

const _$IDEEnumMap = {
  IDE.idea: 'idea',
  IDE.vscode: 'vscode',
};
