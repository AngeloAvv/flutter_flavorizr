/*
 * Copyright (c) 2024 Angelo Cassano
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

import 'package:flutter_flavorizr/src/processors/android/google/firebase/android_firebase_processor.dart';
import 'package:flutter_flavorizr/src/processors/google/firebase/firebase_processor.dart';
import 'package:flutter_flavorizr/src/processors/ios/google/firebase/ios_targets_firebase_processor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mason_logger/mason_logger.dart';

import '../../../test_utils.dart';

void main() {
  late Logger logger;

  setUp(() {
    logger = TestUtils.quietLogger();
  });

  test(
      'Test FirebaseProcessor queues nothing when no flavor has any firebase config',
      () {
    final flavorizr = TestUtils.parseFlavorizr('test_resources/pubspec');

    final processor = FirebaseProcessor(
      androidDestination: 'android',
      iosDestination: 'ios',
      macosDestination: 'macos',
      iosRunnerProject: 'ios/Runner.xcodeproj',
      macosRunnerProject: 'macos/Runner.xcodeproj',
      iosGeneratedFirebaseScriptPath: 'ios/firebase.sh',
      macosGeneratedFirebaseScriptPath: 'macos/firebase.sh',
      config: flavorizr,
      logger: logger,
    );

    expect(processor.processors, isEmpty);
  });

  test(
      'Test FirebaseProcessor queues Android and iOS processors when firebase config is available',
      () {
    final flavorizr = TestUtils.parseFlavorizr(
      'test_resources/ios/ios_firebase_script_processor_test/single_flavor_pubspec',
    );

    final processor = FirebaseProcessor(
      androidDestination: 'android',
      iosDestination: 'ios',
      macosDestination: 'macos',
      iosRunnerProject: 'ios/Runner.xcodeproj',
      macosRunnerProject: 'macos/Runner.xcodeproj',
      iosGeneratedFirebaseScriptPath: 'ios/firebase.sh',
      macosGeneratedFirebaseScriptPath: 'macos/firebase.sh',
      config: flavorizr,
      logger: logger,
    );

    expect(processor.processors.length, 2);
    expect(processor.processors, contains(isA<AndroidFirebaseProcessor>()));
    expect(processor.processors, contains(isA<IOSTargetsFirebaseProcessor>()));
  });

}
