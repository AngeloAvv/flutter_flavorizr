/*
 * Copyright (c) 2022 MyLittleSuite
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

import 'package:flutter_flavorizr/extensions/extensions+map.dart';
import 'package:flutter_flavorizr/parser/models/flavorizr.dart';
import 'package:flutter_flavorizr/parser/models/flavors/flavor.dart';
import 'package:flutter_flavorizr/processors/commons/empty_file_processor.dart';
import 'package:flutter_flavorizr/processors/commons/new_file_string_processor.dart';
import 'package:flutter_flavorizr/processors/commons/queue_processor.dart';
import 'package:flutter_flavorizr/processors/commons/shell_processor.dart';
import 'package:flutter_flavorizr/processors/ios/google/firebase/ios_firebase_processor.dart';
import 'package:flutter_flavorizr/processors/ios/google/firebase/ios_firebase_script_processor.dart';
import 'package:flutter_flavorizr/utils/ios_utils.dart' as IOSUtils;

class IOSTargetsFirebaseProcessor extends QueueProcessor {
  IOSTargetsFirebaseProcessor({
    required String process,
    required String destination,
    required String addFileScript,
    required String runnerProject,
    required String firebaseScript,
    required String generatedFirebaseScriptPath,
    required Flavorizr config,
  }) : super(
          [
            ..._filteredFlavors(config)
                .map(
                  (flavorName, flavor) => MapEntry(
                    flavorName,
                    IOSFirebaseProcessor(
                      flavor.ios.firebase!.config,
                      destination,
                      flavorName,
                      config: config,
                    ),
                  ),
                )
                .values,
            NewFileStringProcessor(
              '$destination/GoogleService-Info.plist',
              EmptyFileProcessor(config: config),
              config: config,
            ),
            ShellProcessor(
              process,
              [
                addFileScript,
                runnerProject,
                IOSUtils.flatPath('$destination/GoogleService-Info.plist'),
              ],
              config: config,
            ),
            NewFileStringProcessor(
              generatedFirebaseScriptPath,
              IOSFirebaseScriptProcessor(config: config),
              config: config,
            ),
            ShellProcessor(
              process,
              [
                firebaseScript,
                runnerProject,
                generatedFirebaseScriptPath,
              ],
              config: config,
            ),
          ],
          config: config,
        );

  @override
  String toString() => 'IOSTargetsFirebaseProcessor';

  static Map<String, Flavor> _filteredFlavors(Flavorizr config) =>
      config.flavors
          .where((flavorName, flavor) => flavor.android.firebase != null);
}
