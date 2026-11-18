import 'package:json_annotation/json_annotation.dart';

part 'adaptive_icon.g.dart';

/// The layers of the adaptive icon of an Android flavor, which are paths of the project.
@JsonSerializable(
  anyMap: true,
  createToJson: false,
  checked: true,
  disallowUnrecognizedKeys: true,
)
class AdaptiveIcon {
  /// The path of the foreground layer.
  @JsonKey(required: true, disallowNullValue: true)
  final String foreground;

  /// The path of the background layer.
  @JsonKey(required: true, disallowNullValue: true)
  final String background;

  /// The path of the monochrome layer, if there is one.
  final String? monochrome;

  /// Creates a AdaptiveIcon.
  const AdaptiveIcon({
    required this.foreground,
    required this.background,
    this.monochrome,
  });

  /// Reads it from [json], the decoded YAML of the configuration.
  factory AdaptiveIcon.fromJson(Map json) => _$AdaptiveIconFromJson(json);
}
