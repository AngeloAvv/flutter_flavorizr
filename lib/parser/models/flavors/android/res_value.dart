import 'package:json_annotation/json_annotation.dart';

part 'res_value.g.dart';

@JsonSerializable(anyMap: true, createToJson: false)
class ResValue {
  @JsonKey(required: true, disallowNullValue: true)
  final String type;

  @JsonKey(required: true, disallowNullValue: true)
  final String value;

  const ResValue({
    required this.type,
    required this.value,
  });

  factory ResValue.fromJson(Map<String, dynamic> json) =>
      _$ResValueFromJson(json);
}
