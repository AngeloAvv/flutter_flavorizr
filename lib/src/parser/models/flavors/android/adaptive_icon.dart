import 'package:json_annotation/json_annotation.dart';

part 'adaptive_icon.g.dart';

@JsonSerializable(anyMap: true, createToJson: false)
class AdaptiveIcon {
  final String foreground;
  final String background;
  final String? monochrome;

  const AdaptiveIcon({
    required this.foreground,
    required this.background,
    this.monochrome,
  });

  factory AdaptiveIcon.fromJson(Map<String, dynamic> json) =>
      _$AdaptiveIconFromJson(json);
}
