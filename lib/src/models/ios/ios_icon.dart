import 'package:flutter_flavorizr/src/models/darwin/icon/darwin_icon.dart';

final class IosIcon extends DarwinIcon {
  const IosIcon(
      {required super.size, required super.idiom, required super.scale});

  @override
  String get fileName {
    final digits = size.truncate() == size ? 0 : 1;
    final strSize = size.toStringAsFixed(digits);

    return 'Icon-App-${strSize}x$strSize@${scale}x.png';
  }
}
