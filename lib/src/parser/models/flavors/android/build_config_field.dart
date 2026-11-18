import 'package:json_annotation/json_annotation.dart';

part 'build_config_field.g.dart';

/// A `buildConfigField` of an Android flavor.
@JsonSerializable(
  anyMap: true,
  createToJson: false,
  checked: true,
  disallowUnrecognizedKeys: true,
)
class BuildConfigField {
  /// The type of the field.
  @JsonKey(required: true, disallowNullValue: true)
  final String type;

  /// The value of the field.
  @JsonKey(required: true, disallowNullValue: true)
  final String value;

  /// The value as Groovy writes it.
  String get legacyWrappedValue {
    if (type == 'String') {
      return '"\\"$value\\""';
    }
    if (type == 'char') {
      return "'\\'$value\\''";
    }
    return "\"$value\"";
  }

  /// The value as a string literal of the build script.
  String get wrappedValue {
    if (type == 'String') {
      return '"\\"$value\\""';
    }
    if (type == 'char') {
      return '"\\\'$value\\\'"';
    }
    return "\"$value\"";
  }

  /// Creates a BuildConfigField.
  const BuildConfigField({required this.type, required this.value});

  /// Reads it from [json], the decoded YAML of the configuration.
  factory BuildConfigField.fromJson(Map json) =>
      _$BuildConfigFieldFromJson(json);
}
