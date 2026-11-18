import 'package:json_annotation/json_annotation.dart';

part 'res_value.g.dart';

/// A `resValue` of an Android flavor.
@JsonSerializable(
  anyMap: true,
  createToJson: false,
  checked: true,
  disallowUnrecognizedKeys: true,
)
class ResValue {
  /// The type of the resource.
  @JsonKey(required: true, disallowNullValue: true)
  final String type;

  /// The value of the resource.
  @JsonKey(required: true, disallowNullValue: true)
  final String value;

  /// Creates a ResValue.
  const ResValue({required this.type, required this.value});

  /// The value with its quotes escaped, for the build script.
  String get wrappedValue => value.replaceAll('\'', '\\\\\'');

  /// Reads it from [json], the decoded YAML of the configuration.
  factory ResValue.fromJson(Map json) => _$ResValueFromJson(json);
}
