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

import 'dart:io';

import 'package:flutter_flavorizr/parser/models/pubspec.dart';
import 'package:flutter_flavorizr/processors/android/android_build_gradle_processor.dart';
import 'package:flutter_flavorizr/processors/android/android_dummy_assets_processor.dart';
import 'package:flutter_flavorizr/processors/android/android_manifest_processor.dart';
import 'package:flutter_flavorizr/processors/commons/abstract_processor.dart';
import 'package:flutter_flavorizr/processors/commons/copy_file_processor.dart';
import 'package:flutter_flavorizr/processors/commons/copy_folder_processor.dart';
import 'package:flutter_flavorizr/processors/commons/delete_file_processor.dart';
import 'package:flutter_flavorizr/processors/commons/download_file_processor.dart';
import 'package:flutter_flavorizr/processors/commons/existing_file_string_processor.dart';
import 'package:flutter_flavorizr/processors/commons/new_file_string_processor.dart';
import 'package:flutter_flavorizr/processors/commons/queue_processor.dart';
import 'package:flutter_flavorizr/processors/commons/unzip_file_processor.dart';
import 'package:flutter_flavorizr/processors/flutter/flutter_flavors_processor.dart';
import 'package:flutter_flavorizr/processors/flutter/target/flutter_targets_file_processor.dart';
import 'package:flutter_flavorizr/processors/google/firebase/firebase_processor.dart';
import 'package:flutter_flavorizr/processors/ide/ide_processor.dart';
import 'package:flutter_flavorizr/processors/ios/build_configuration/ios_build_configurations_targets_processor.dart';
import 'package:flutter_flavorizr/processors/ios/dummy_assets/ios_dummy_assets_targets_processor.dart';
import 'package:flutter_flavorizr/processors/ios/ios_plist_processor.dart';
import 'package:flutter_flavorizr/processors/ios/ios_schemas_processor.dart';
import 'package:flutter_flavorizr/processors/ios/launch_screen/ios_targets_launchscreen_file_processor.dart';
import 'package:flutter_flavorizr/processors/ios/xcconfig/ios_xcconfig_targets_file_processor.dart';
import 'package:flutter_flavorizr/utils/constants.dart';

class Processor extends AbstractProcessor<void> {
  final Map<String, AbstractProcessor<void>> _availableProcessors;

  final Pubspec _pubspec;
  static const List<String> defaultInstructionSet = [
    // Prepare
    'assets:download',
    'assets:extract',

    // Android
    'android:androidManifest',
    'android:buildGradle',
    'android:dummyAssets',

    // Flutter
    'flutter:flavors',
    'flutter:app',
    'flutter:pages',
    'flutter:targets',

    // iOS
    'ios:xcconfig',
    'ios:buildTargets',
    'ios:schema',
    'ios:dummyAssets',
    'ios:plist',
    'ios:launchScreen',

    // Google
    'google:firebase',

    // Cleanup
    'assets:clean',

    // IDE
    'ide:config'
  ];

  Processor(this._pubspec) : _availableProcessors = _initAvailableProcessors(_pubspec);

  @override
  void execute() async {
    final List<String> instructions =
        _pubspec.flavorizr.instructions ?? defaultInstructionSet;

    for (String instruction in instructions) {
      stdout.writeln('Executing task $instruction');

      AbstractProcessor? processor = _availableProcessors[instruction];
      if (processor == null) {
        stderr.writeln('Cannot execute processor $instruction');
      }

      await processor?.execute();

      stdout.writeln();
    }
  }

  static Map<String, AbstractProcessor<void>> _initAvailableProcessors(Pubspec pubspec) {
    return {
      // Commons
      'assets:download': DownloadFileProcessor(
        pubspec.flavorizr.assetsUrl,
        K.assetsZipPath,
      ),
      'assets:extract': UnzipFileProcessor(
        K.assetsZipPath,
        K.tempPath,
      ),
      'assets:clean': QueueProcessor([
        DeleteFileProcessor(K.assetsZipPath),
        DeleteFileProcessor(K.tempPath),
      ]),

      // Android
      'android:androidManifest': ExistingFileStringProcessor(
        K.androidManifestPath,
        AndroidManifestProcessor(),
      ),
      'android:buildGradle': ExistingFileStringProcessor(
        K.androidBuildGradlePath,
        AndroidBuildGradleProcessor(pubspec.flavorizr),
      ),
      'android:dummyAssets': AndroidDummyAssetsProcessor(
        K.tempAndroidResPath,
        K.androidSrcPath,
        pubspec.flavorizr.flavors,
      ),

      //Flutter
      'flutter:flavors': NewFileStringProcessor(
        K.flutterFlavorPath,
        FlutterFlavorsProcessor(pubspec.flavorizr.flavors),
      ),
      'flutter:app': CopyFileProcessor(
        K.tempFlutterAppPath,
        K.flutterAppPath,
      ),
      'flutter:pages': CopyFolderProcessor(
        K.tempFlutterPagesPath,
        K.flutterPagesPath,
      ),
      'flutter:targets': FlutterTargetsFileProcessor(
        K.tempFlutterMainPath,
        K.flutterPath,
        pubspec.flavorizr.flavors.keys,
      ),

      //iOS
      'ios:xcconfig': IOSXCConfigTargetsFileProcessor(
        'ruby',
        K.tempiOSAddFileScriptPath,
        K.iOSRunnerProjectPath,
        K.iOSFlutterPath,
        pubspec.flavorizr.flavors,
      ),
      'ios:buildTargets': IOSBuildConfigurationsTargetsProcessor(
        'ruby',
        K.tempiOSAddBuildConfigurationScriptPath,
        K.iOSRunnerProjectPath,
        K.iOSFlutterPath,
        pubspec.flavorizr,
      ),
      'ios:schema': IOSSchemasProcessor(
        'ruby',
        K.tempiOSCreateSchemeScriptPath,
        K.iOSRunnerProjectPath,
        pubspec.flavorizr.flavors.keys,
      ),
      'ios:dummyAssets': IOSDummyAssetsTargetsProcessor(
        K.tempiOSAssetsPath,
        K.iOSAssetsPath,
        pubspec.flavorizr.flavors,
      ),
      'ios:plist': ExistingFileStringProcessor(
        K.iOSPListPath,
        IOSPListProcessor(),
      ),
      'ios:launchScreen': IOSTargetsLaunchScreenFileProcessor(
        'ruby',
        K.tempiOSAddFileScriptPath,
        K.iOSRunnerProjectPath,
        K.tempiOSLaunchScreenPath,
        K.iOSRunnerPath,
        pubspec.flavorizr.flavors.keys,
      ),

      // Google
      'google:firebase': FirebaseProcessor(
        process: 'ruby',
        androidDestination: K.androidSrcPath,
        iosDestination: K.iOSRunnerPath,
        addFileScript: K.tempiOSAddFileScriptPath,
        runnerProject: K.iOSRunnerProjectPath,
        firebaseScript: K.tempiOSAddFirebaseBuildPhaseScriptPath,
        generatedFirebaseScriptPath: K.tempiOSFirebaseScriptPath,
        flavors: pubspec.flavorizr.flavors,
      ),

      // IDE
      'ide:config': IDEProcessor(
        ide: pubspec.flavorizr.ide,
        flavors: pubspec.flavorizr.flavors.keys,
      ),
    };
  }
}
