/*
 * Copyright (c) 2023 Angelo Cassano
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

import 'package:flutter_flavorizr/parser/models/flavorizr.dart';
import 'package:flutter_flavorizr/processors/android/android_build_gradle_processor.dart';
import 'package:flutter_flavorizr/processors/android/android_dummy_assets_processor.dart';
import 'package:flutter_flavorizr/processors/android/android_manifest_processor.dart';
import 'package:flutter_flavorizr/processors/android/icons/android_icons_processor.dart';
import 'package:flutter_flavorizr/processors/commons/abstract_processor.dart';
import 'package:flutter_flavorizr/processors/commons/copy_file_processor.dart';
import 'package:flutter_flavorizr/processors/commons/copy_folder_processor.dart';
import 'package:flutter_flavorizr/processors/commons/delete_file_processor.dart';
import 'package:flutter_flavorizr/processors/commons/download_file_processor.dart';
import 'package:flutter_flavorizr/processors/commons/existing_file_string_processor.dart';
import 'package:flutter_flavorizr/processors/commons/new_file_string_processor.dart';
import 'package:flutter_flavorizr/processors/commons/queue_processor.dart';
import 'package:flutter_flavorizr/processors/commons/unzip_file_processor.dart';
import 'package:flutter_flavorizr/processors/darwin/darwin_schemas_processor.dart';
import 'package:flutter_flavorizr/processors/flutter/flutter_flavors_processor.dart';
import 'package:flutter_flavorizr/processors/flutter/target/flutter_targets_file_processor.dart';
import 'package:flutter_flavorizr/processors/google/firebase/firebase_processor.dart';
import 'package:flutter_flavorizr/processors/huawei/agconnect/agconnect_processor.dart';
import 'package:flutter_flavorizr/processors/ide/ide_processor.dart';
import 'package:flutter_flavorizr/processors/ios/build_configuration/ios_build_configurations_targets_processor.dart';
import 'package:flutter_flavorizr/processors/ios/dummy_assets/ios_dummy_assets_targets_processor.dart';
import 'package:flutter_flavorizr/processors/ios/icons/ios_icons_processor.dart';
import 'package:flutter_flavorizr/processors/ios/ios_plist_processor.dart';
import 'package:flutter_flavorizr/processors/ios/launch_screen/ios_targets_launchscreen_file_processor.dart';
import 'package:flutter_flavorizr/processors/ios/xcconfig/ios_xcconfig_targets_file_processor.dart';
import 'package:flutter_flavorizr/processors/macos/build_configuration/macos_build_configurations_targets_processor.dart';
import 'package:flutter_flavorizr/processors/macos/configs/macos_configs_targets_file_processor.dart';
import 'package:flutter_flavorizr/processors/macos/dummy_assets/macos_dummy_assets_targets_processor.dart';
import 'package:flutter_flavorizr/processors/macos/icons/macos_icons_processor.dart';
import 'package:flutter_flavorizr/processors/macos/macos_plist_processor.dart';
import 'package:flutter_flavorizr/processors/macos/xcconfig/macos_xcconfig_targets_file_processor.dart';
import 'package:flutter_flavorizr/utils/constants.dart';

class Processor extends AbstractProcessor<void> {
  final Map<String, AbstractProcessor<void>> _availableProcessors;

  final Flavorizr _flavorizr;
  static const List<String> defaultInstructionSet = [
    // Prepare
    'assets:download',
    'assets:extract',

    // Android
    'android:androidManifest',
    'android:buildGradle',
    'android:dummyAssets',
    'android:icons',

    // Flutter
    'flutter:flavors',
    'flutter:app',
    'flutter:pages',
    'flutter:main',
    'flutter:targets',

    // iOS
    'ios:xcconfig',
    'ios:buildTargets',
    'ios:schema',
    'ios:dummyAssets',
    'ios:icons',
    'ios:plist',
    'ios:launchScreen',

    // macOS
    'macos:xcconfig',
    'macos:configs',
    'macos:buildTargets',
    'macos:schema',
    'macos:dummyAssets',
    'macos:icons',
    'macos:plist',

    // Google
    'google:firebase',

    // Huawei
    'huawei:agconnect',

    // Cleanup
    'assets:clean',

    // IDE
    'ide:config'
  ];

  Processor(this._flavorizr)
      : _availableProcessors = _initAvailableProcessors(_flavorizr),
        super(_flavorizr);

  @override
  void execute() async {
    final instructions =
        _flavorizr.instructions ?? defaultInstructionSet;

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

  static Map<String, AbstractProcessor<void>> _initAvailableProcessors(
      Flavorizr flavorizr) {
    return {
      // Commons
      'assets:download': DownloadFileProcessor(
        K.assetsZipPath,
        config: flavorizr,
      ),
      'assets:extract': UnzipFileProcessor(
        K.assetsZipPath,
        K.tempPath,
        config: flavorizr,
      ),
      'assets:clean': QueueProcessor(
        [
          DeleteFileProcessor(
            K.assetsZipPath,
            config: flavorizr,
          ),
          DeleteFileProcessor(
            K.tempPath,
            config: flavorizr,
          ),
        ],
        config: flavorizr,
      ),

      // Android
      'android:androidManifest': ExistingFileStringProcessor(
        K.androidManifestPath,
        AndroidManifestProcessor(config: flavorizr),
        config: flavorizr,
      ),
      'android:buildGradle': ExistingFileStringProcessor(
        K.androidBuildGradlePath,
        AndroidBuildGradleProcessor(
          config: flavorizr,
        ),
        config: flavorizr,
      ),
      'android:dummyAssets': AndroidDummyAssetsProcessor(
        K.tempAndroidResPath,
        K.androidSrcPath,
        config: flavorizr,
      ),
      'android:icons': AndroidIconsProcessor(
        config: flavorizr,
      ),

      //Flutter
      'flutter:flavors': NewFileStringProcessor(
        K.flutterFlavorPath,
        FlutterFlavorsProcessor(config: flavorizr),
        config: flavorizr,
      ),
      'flutter:app': CopyFileProcessor(
        K.tempFlutterAppPath,
        K.flutterAppPath,
        config: flavorizr,
      ),
      'flutter:pages': CopyFolderProcessor(
        K.tempFlutterPagesPath,
        K.flutterPagesPath,
        config: flavorizr,
      ),
      'flutter:main': CopyFileProcessor(
        K.tempFlutterMainPath,
        K.flutterMainPath,
        config: flavorizr,
      ),
      'flutter:targets': FlutterTargetsFileProcessor(
        K.tempFlutterMainTargetPath,
        K.flutterPath,
        config: flavorizr,
      ),

      //iOS
      'ios:xcconfig': IOSXCConfigTargetsFileProcessor(
        'ruby',
        K.tempDarwinAddFileScriptPath,
        K.iOSRunnerProjectPath,
        K.iOSFlutterPath,
        config: flavorizr,
      ),
      'ios:buildTargets': IOSBuildConfigurationsTargetsProcessor(
        'ruby',
        K.tempDarwinAddBuildConfigurationScriptPath,
        K.iOSRunnerProjectPath,
        K.iOSFlutterPath,
        config: flavorizr,
      ),
      'ios:schema': DarwinSchemasProcessor(
        'ruby',
        K.tempDarwinCreateSchemeScriptPath,
        K.iOSRunnerProjectPath,
        config: flavorizr,
      ),
      'ios:dummyAssets': IOSDummyAssetsTargetsProcessor(
        K.tempiOSAssetsPath,
        K.iOSAssetsPath,
        config: flavorizr,
      ),
      'ios:icons': IOSIconsProcessor(
        config: flavorizr,
      ),
      'ios:plist': ExistingFileStringProcessor(
        K.iOSPListPath,
        IOSPListProcessor(config: flavorizr),
        config: flavorizr,
      ),
      'ios:launchScreen': IOSTargetsLaunchScreenFileProcessor(
        'ruby',
        K.tempDarwinAddFileScriptPath,
        K.iOSRunnerProjectPath,
        K.tempiOSLaunchScreenPath,
        K.iOSRunnerPath,
        config: flavorizr,
      ),

      // MacOS
      'macos:xcconfig': MacOSXCConfigTargetsFileProcessor(
        'ruby',
        K.tempDarwinAddFileScriptPath,
        K.macOSRunnerProjectPath,
        K.macOSFlutterPath,
        config: pubspec.flavorizr,
      ),
      'macos:configs': MacOSConfigsTargetsFileProcessor(
        'ruby',
        K.tempDarwinAddFileScriptPath,
        K.macOSRunnerProjectPath,
        K.macOSConfigsPath,
        config: pubspec.flavorizr,
      ),
      'macos:buildTargets': MacOSBuildConfigurationsTargetsProcessor(
        'ruby',
        K.tempDarwinAddBuildConfigurationScriptPath,
        K.macOSRunnerProjectPath,
        K.macOSConfigsPath,
        config: pubspec.flavorizr,
      ),
      'macos:schema': DarwinSchemasProcessor(
        'ruby',
        K.tempDarwinCreateSchemeScriptPath,
        K.macOSRunnerProjectPath,
        config: pubspec.flavorizr,
      ),
      'macos:dummyAssets': MacOSDummyAssetsTargetsProcessor(
        K.tempMacOSAssetsPath,
        K.macOSAssetsPath,
        config: pubspec.flavorizr,
      ),
      'macos:icons': MacOSIconsProcessor(
        config: pubspec.flavorizr,
      ),
      'macos:plist': ExistingFileStringProcessor(
        K.macOSPlistPath,
        MacOSPListProcessor(config: pubspec.flavorizr),
        config: pubspec.flavorizr,
      ),

      // Google
      'google:firebase': FirebaseProcessor(
        process: 'ruby',
        androidDestination: K.androidSrcPath,
        iosDestination: K.iOSRunnerPath,
        macosDestination: K.macOSRunnerPath,
        addFileScript: K.tempDarwinAddFileScriptPath,
        iosRunnerProject: K.iOSRunnerProjectPath,
        macosRunnerProject: K.macOSRunnerProjectPath,
        firebaseScript: K.tempDarwinAddFirebaseBuildPhaseScriptPath,
        iosGeneratedFirebaseScriptPath: K.iOSFirebaseScriptPath,
        macosGeneratedFirebaseScriptPath: K.macOSFirebaseScriptPath,
        config: flavorizr,
      ),

      // Huawei
      'huawei:agconnect': AGConnectProcessor(
        destination: K.androidSrcPath,
        config: flavorizr,
      ),

      // IDE
      'ide:config': IDEProcessor(
        config: flavorizr,
      ),
    };
  }
}
