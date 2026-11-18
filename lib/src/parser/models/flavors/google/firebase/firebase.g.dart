// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'firebase.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Firebase _$FirebaseFromJson(Map json) => $checkedCreate('Firebase', json, (
  $checkedConvert,
) {
  $checkKeys(
    json,
    allowedKeys: const ['config'],
    requiredKeys: const ['config'],
    disallowNullValues: const ['config'],
  );
  final val = Firebase(config: $checkedConvert('config', (v) => v as String));
  return val;
});
