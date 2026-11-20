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

import 'dart:io';

import 'package:flutter_flavorizr/src/engine/processors/darwin/info_plist_editor.dart';
import 'package:flutter_flavorizr/src/utils/constants.dart';
import 'package:path/path.dart' as p;

/// The variable of the xcconfig of every flavor that keeps the launch
/// storyboard the project had before flavorizr pointed `Info.plist` at
/// `$(LAUNCH_SCREEN_NAME)`.
const defaultLaunchScreenVariable = 'DEFAULT_LAUNCH_SCREEN_NAME';

final _kept = RegExp(
  '^$defaultLaunchScreenVariable=(.+?)\\s*\$',
  multiLine: true,
);

/// The launch storyboard the iOS project had, as `UILaunchStoryboardName` spells
/// it: the one a flavor without a launch screen keeps, and the one the plist
/// goes back to when no flavor has a launch screen anymore.
///
/// It is the value `Info.plist` has (the one of [plistSource] when it is given,
/// otherwise the one of the project in [projectRoot]), whatever it is: the
/// storyboard of Flutter, one with another name, or the one 2.x set. Once the
/// plist points at `$(LAUNCH_SCREEN_NAME)` it is not there anymore, so it is
/// the one an earlier run kept in the xcconfig of the flavors
/// ([defaultLaunchScreenVariable]), and `LaunchScreen`, the one `flutter create`
/// makes, when nothing says.
///
/// It only reads the project: the files it looks at are the ones the run has not
/// changed yet.
String originalLaunchStoryboardName(
  Directory projectRoot, {
  String? plistSource,
}) {
  try {
    final source =
        plistSource ??
        File(p.join(projectRoot.path, K.iOSPListPath)).readAsStringSync();
    final current = InfoPlistEditor.readStrings(source, [
      InfoPlistEditor.launchStoryboardName,
    ])[InfoPlistEditor.launchStoryboardName];

    if (current != null &&
        current.isNotEmpty &&
        current != InfoPlistEditor.launchStoryboardNameValue) {
      return current;
    }
  } on Object {
    // A plist that is missing or cannot be read is what the patch of the plist
    // reports: here it only means there is nothing to keep.
  }

  final kept = keptLaunchStoryboardName(projectRoot);

  if (kept != null) return kept;

  return InfoPlistEditor.defaultLaunchStoryboardNameValue;
}

/// The launch storyboard an earlier run kept in the xcconfig of the flavors
/// ([defaultLaunchScreenVariable]), or `null` when none did.
String? keptLaunchStoryboardName(Directory projectRoot) {
  final flutter = Directory(p.join(projectRoot.path, K.iOSFlutterPath));

  if (!flutter.existsSync()) return null;

  final files =
      flutter
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.xcconfig'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  for (final file in files) {
    try {
      final kept = _kept.firstMatch(file.readAsStringSync())?.group(1);

      if (kept != null) return kept;
    } on FileSystemException {
      continue;
    }
  }

  return null;
}

/// Whether `Info.plist` of the project in [projectRoot] points at
/// `$(LAUNCH_SCREEN_NAME)` now, so that the xcconfig of every flavor has to
/// define it, whatever the configuration says.
bool launchStoryboardIsPointedAtFlavors(Directory projectRoot) {
  try {
    final source = File(
      p.join(projectRoot.path, K.iOSPListPath),
    ).readAsStringSync();

    return InfoPlistEditor.readStrings(source, [
          InfoPlistEditor.launchStoryboardName,
        ])[InfoPlistEditor.launchStoryboardName] ==
        InfoPlistEditor.launchStoryboardNameValue;
  } on Object {
    return false;
  }
}
