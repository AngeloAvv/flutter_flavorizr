import 'package:json_annotation/json_annotation.dart';

part 'adaptive_icon.g.dart';

@JsonSerializable(
  anyMap: true,
  createToJson: false,
  checked: true,
  disallowUnrecognizedKeys: true,
)
class AdaptiveIcon {
  @JsonKey(required: true, disallowNullValue: true)
  final String foreground;

  @JsonKey(required: true, disallowNullValue: true)
  final String background;

  final String? monochrome;

  const AdaptiveIcon({
    required this.foreground,
    required this.background,
    this.monochrome,
  });

  factory AdaptiveIcon.fromJson(Map json) => _$AdaptiveIconFromJson(json);
}
