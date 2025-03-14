import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:flutter_flavorizr/src/parser/models/flavors/android/adaptive_icon.dart';
import 'package:flutter_flavorizr/src/processors/commons/string_processor.dart';

class AndroidGenerateIclauncherXmlProcessor extends StringProcessor {
  AndroidGenerateIclauncherXmlProcessor({
    required this.adaptiveIcon,
    required Flavorizr config,
  }) : super(config: config);

  AdaptiveIcon adaptiveIcon;

  @override
  String execute() {
    if (adaptiveIcon.monochrome != null) {
      return '<?xml version="1.0" encoding="utf-8"?>'
          '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">'
          '<background android:drawable="@drawable/ic_launcher_background" />'
          '<foreground android:drawable="@drawable/ic_launcher_foreground" />'
          '<monochrome android:drawable="@drawable/ic_launcher_monochrome" />'
          '</adaptive-icon>';
    } else {
      return '<?xml version="1.0" encoding="utf-8"?>'
          '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">'
          '<background android:drawable="@drawable/ic_launcher_background" />'
          '<foreground android:drawable="@drawable/ic_launcher_foreground" />'
          '</adaptive-icon>';
    }
  }

  @override
  String toString() => 'AndroidGenerateIclauncherXmlProcessor';
}
