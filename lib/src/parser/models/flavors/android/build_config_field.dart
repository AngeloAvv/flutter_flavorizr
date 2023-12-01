import 'package:json_annotation/json_annotation.dart';

part 'build_config_field.g.dart';

@JsonSerializable(anyMap: true, createToJson: false)
class BuildConfigField {
  @JsonKey(required: true, disallowNullValue: true)
  final String type;

  @JsonKey(required: true, disallowNullValue: true)
  final String value;

  String get wrappedValue {
    if (type == 'String') {
      return '"\\"$value\\""';
    }
    if (type == 'char') {
      return "'\\'$value\\''";
    }
    return "\"$value\"";
  }

  const BuildConfigField({
    required this.type,
    required this.value,
  });

  factory BuildConfigField.fromJson(Map<String, dynamic> json) =>
      _$BuildConfigFieldFromJson(json);
}
