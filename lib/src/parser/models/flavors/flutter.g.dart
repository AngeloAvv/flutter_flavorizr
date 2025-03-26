// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'flutter.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Flutter _$FlutterFromJson(Map json) {
  $checkKeys(
    json,
    disallowNullValues: const ['entrypoint'],
  );
  return Flutter(
    entrypoint: json['entrypoint'] as String? ?? K.flutterMainPath,
  );
}
