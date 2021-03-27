/*
 * Copyright (c) 2021 MyLittleSuite
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

import 'package:flutter_flavorizr/parser/models/flavors/flavor.dart';
import 'package:flutter_flavorizr/processors/android/google/firebase/android_firebase_processor.dart';
import 'package:flutter_flavorizr/processors/commons/queue_processor.dart';
import 'package:flutter_flavorizr/processors/ios/google/firebase/ios_targets_firebase_processor.dart';

class FirebaseProcessor extends QueueProcessor {
  FirebaseProcessor({
    String process,
    String androidDestination,
    String iosDestination,
    String addFileScript,
    String runnerProject,
    String firebaseScript,
    String generatedFirebaseScriptPath,
    Map<String, Flavor> flavors,
  }) : super(
          [
            ...flavors
                .map(
                  (String flavorName, Flavor flavor) => MapEntry(
                    flavorName,
                    flavor.android?.firebase != null
                        ? AndroidFirebaseProcessor(
                            flavor.android?.firebase?.config,
                            androidDestination,
                            flavorName,
                          )
                        : null,
                  ),
                )
                .values
                .where((processor) => processor != null),
            IOSTargetsFirebaseProcessor(
              process: process,
              destination: iosDestination,
              addFileScript: addFileScript,
              runnerProject: runnerProject,
              firebaseScript: firebaseScript,
              generatedFirebaseScriptPath: generatedFirebaseScriptPath,
              flavors: flavors,
            ),
          ],
        );

  @override
  String toString() => 'FirebaseProcessor';
}
