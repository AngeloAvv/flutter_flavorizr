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

import 'package:dart_xcodeproj/dart_xcodeproj.dart';
import 'package:path/path.dart' as p;

/// The `project.pbxproj` of the iOS example without what 2.x added to it for its
/// flavors (`apple` and `banana`): a project nobody ran flavorizr on, saved by
/// `dart_xcodeproj`. [temp] is a directory the test owns.
///
/// The objects are taken out with `removeFromProject`, which is not what it is
/// here to test, so the result is checked to hold nothing of the flavors.
Future<String> pristineIosPbxproj(Directory temp) async {
  final bundle = Directory(p.join(temp.path, 'pristine', 'Runner.xcodeproj'))
    ..createSync(recursive: true);

  File(
    'example/ios/Runner.xcodeproj/project.pbxproj',
  ).copySync(p.join(bundle.path, 'project.pbxproj'));

  final project = await XcodeProject.open(bundle.path);
  final flavored = RegExp(r'(apple|banana)', caseSensitive: false);

  for (final object in project.objectsByUuid.values.toList()) {
    final removable = switch (object) {
      XCBuildConfiguration() => RegExp(
        r'-(apple|banana)$',
      ).hasMatch(object.name ?? ''),
      PBXFileReference() => flavored.hasMatch(p.basename(object.path ?? '')),
      _ => false,
    };

    if (removable) object.removeFromProject();
  }

  await project.save();

  final text = File(p.join(bundle.path, 'project.pbxproj')).readAsStringSync();

  if (text.contains(RegExp(r'banana|-apple|apple[A-Z]'))) {
    throw StateError('the pristine project still holds flavored objects');
  }

  return text;
}
