// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'firebase.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Firebase _$FirebaseFromJson(Map json) {
  $checkKeys(
    json,
    requiredKeys: const ['config'],
    disallowNullValues: const ['config'],
  );
  return Firebase(
    config: json['config'] as String,
  );
}
