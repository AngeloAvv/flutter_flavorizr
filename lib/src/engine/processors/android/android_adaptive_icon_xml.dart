/*
 * Copyright (c) 2026 Angelo Cassano
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use,
 * copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following
 * conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 */

import 'package:flutter_flavorizr/src/parser/models/flavors/android/adaptive_icon.dart';

/// The XML of `mipmap-anydpi-v26/ic_launcher.xml` for [icon]: its background
/// and foreground, and its monochrome layer when it has one.
String androidAdaptiveIconXml(AdaptiveIcon icon) {
  final buffer = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="utf-8"?>')
    ..writeln(
      '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">',
    )
    ..writeln(
      '<background android:drawable="@drawable/ic_launcher_background" />',
    )
    ..writeln(
      '<foreground android:drawable="@drawable/ic_launcher_foreground" />',
    );

  if (icon.monochrome != null) {
    buffer.writeln(
      '<monochrome android:drawable="@drawable/ic_launcher_monochrome" />',
    );
  }

  buffer.writeln('</adaptive-icon>');

  return buffer.toString();
}
