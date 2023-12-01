import 'package:json_annotation/json_annotation.dart';

part 'adaptive_icon.g.dart';

@JsonSerializable(anyMap: true, createToJson: false)
class AdaptiveIcon {
  final String foreground;
  final String background;

  AdaptiveIcon({required this.foreground, required this.background});

  factory AdaptiveIcon.fromJson(Map<String, dynamic> json) =>
      _$AdaptiveIconFromJson(json);
}
