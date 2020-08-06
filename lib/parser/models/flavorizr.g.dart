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
        'https://github.com/AngeloAvv/flutter_flavorizr/releases/download/v1.0.7/assets.zip',
    ide: _$enumDecodeNullable(_$IDEEnumMap, json['ide']),
  );
}

T _$enumDecode<T>(
  Map<T, dynamic> enumValues,
  dynamic source, {
  T unknownValue,
}) {
  if (source == null) {
    throw ArgumentError('A value must be provided. Supported values: '
        '${enumValues.values.join(', ')}');
  }

  final value = enumValues.entries
      .singleWhere((e) => e.value == source, orElse: () => null)
      ?.key;

  if (value == null && unknownValue == null) {
    throw ArgumentError('`$source` is not one of the supported values: '
        '${enumValues.values.join(', ')}');
  }
  return value ?? unknownValue;
}

T _$enumDecodeNullable<T>(
  Map<T, dynamic> enumValues,
  dynamic source, {
  T unknownValue,
}) {
  if (source == null) {
    return null;
  }
  return _$enumDecode<T>(enumValues, source, unknownValue: unknownValue);
}

const _$IDEEnumMap = {
  IDE.idea: 'idea',
  IDE.vscode: 'vscode',
};
