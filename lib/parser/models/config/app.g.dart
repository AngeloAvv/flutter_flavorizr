// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

App _$AppFromJson(Map json) => App(
      android: json['android'] == null
          ? null
          : Android.fromJson(Map<String, dynamic>.from(json['android'] as Map)),
      ios: json['ios'] == null
          ? null
          : IOS.fromJson(Map<String, dynamic>.from(json['ios'] as Map)),
    );
