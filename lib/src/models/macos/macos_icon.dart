import 'package:flutter_flavorizr/src/models/darwin/icon/darwin_icon.dart';

final class MacosIcon extends DarwinIcon {
  const MacosIcon(
      {required super.size, required super.idiom, required super.scale});

  @override
  String get fileName => 'app_icon_${(size * scale).toInt()}.png';
}
