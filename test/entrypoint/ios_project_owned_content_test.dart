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

import 'package:flutter_flavorizr/src/engine/processors/darwin/build_settings_owned_content.dart';
import 'package:flutter_flavorizr/src/engine/processors/darwin/xcconfig_references.dart';
import 'package:flutter_flavorizr/src/engine/processors/google/firebase_processors.dart';
import 'package:flutter_flavorizr/src/entrypoint/processor_registry.dart';
import 'package:test/test.dart';

import '../engine/darwin/pristine_project.dart';

void main() {
  late Directory temp;

  setUpAll(
    () => temp = Directory.systemTemp.createTempSync('flavorizr_owned_'),
  );
  tearDownAll(() => temp.deleteSync(recursive: true));

  test('is what it was before the launch screens when the project has no '
      'reference to a storyboard of a flavor', () async {
    final source = await pristineIosPbxproj(temp);

    expect(
      iosProjectOwnedContent(source),
      [
        xcconfigReferencesOwnedContent(source),
        buildSettingsOwnedContent(source),
        firebaseOwnedContent(source, 'ios'),
      ].join('\n'),
    );
  });

  test('has the references to the storyboards of the flavors, when it has '
      'some', () {
    final source = File(
      'test_resources/example_2x/ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();

    expect(
      iosProjectOwnedContent(source),
      contains('appleLaunchScreen.storyboard'),
    );
  });
}
