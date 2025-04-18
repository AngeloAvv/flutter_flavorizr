import 'package:flutter_flavorizr/src/parser/models/flavors/android/adaptive_icon.dart';
import 'package:flutter_flavorizr/src/processors/commons/string_processor.dart';

class AndroidGenerateIclauncherXmlProcessor extends StringProcessor {
  final AdaptiveIcon adaptiveIcon;

  AndroidGenerateIclauncherXmlProcessor({
    required this.adaptiveIcon,
    required super.config,
    required super.logger,
  });

  @override
  String execute() {
    final StringBuffer buffer = StringBuffer();

    logger.detail(
        '[$AndroidGenerateIclauncherXmlProcessor] Generating XML adaptive icon');

    buffer.writeln('<?xml version="1.0" encoding="utf-8"?>');
    buffer.writeln(
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">');
    buffer.writeln(
        '<background android:drawable="@drawable/ic_launcher_background" />');
    buffer.writeln(
        '<foreground android:drawable="@drawable/ic_launcher_foreground" />');
    if (adaptiveIcon.monochrome != null) {
      buffer.writeln(
          '<monochrome android:drawable="@drawable/ic_launcher_monochrome" />');
    }
    buffer.writeln('</adaptive-icon>');

    logger.detail(
        '[$AndroidGenerateIclauncherXmlProcessor] Adaptive icon XML generated');

    return buffer.toString();
  }

  @override
  String toString() => 'AndroidGenerateIclauncherXmlProcessor: { '
      'adaptiveIcon: $adaptiveIcon }';
}
