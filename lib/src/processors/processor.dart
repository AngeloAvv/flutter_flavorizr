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

import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:flutter_flavorizr/src/processors/android/android_dummy_assets_processor.dart';
import 'package:flutter_flavorizr/src/processors/android/android_manifest_processor.dart';
import 'package:flutter_flavorizr/src/processors/android/build_gradle/android_build_kotlin_processor.dart';
import 'package:flutter_flavorizr/src/processors/android/build_gradle/android_build_legacy_processor.dart';
import 'package:flutter_flavorizr/src/processors/android/build_gradle/android_flavorizr_gradle_processor.dart';
import 'package:flutter_flavorizr/src/processors/android/build_gradle/android_flavorizr_kotlin_processor.dart';
import 'package:flutter_flavorizr/src/processors/android/build_gradle/android_flavorizr_legacy_processor.dart';
import 'package:flutter_flavorizr/src/processors/android/icons/android_icons_processor.dart';
import 'package:flutter_flavorizr/src/processors/commons/abstract_processor.dart';
import 'package:flutter_flavorizr/src/processors/commons/apply_processor_by_existing_file_processor.dart';
import 'package:flutter_flavorizr/src/processors/commons/copy_file_processor.dart';
import 'package:flutter_flavorizr/src/processors/commons/copy_folder_processor.dart';
import 'package:flutter_flavorizr/src/processors/commons/delete_file_processor.dart';
import 'package:flutter_flavorizr/src/processors/commons/download_file_processor.dart';
import 'package:flutter_flavorizr/src/processors/commons/dynamic_file_string_processor.dart';
import 'package:flutter_flavorizr/src/processors/commons/existing_file_string_processor.dart';
import 'package:flutter_flavorizr/src/processors/commons/new_file_string_processor.dart';
import 'package:flutter_flavorizr/src/processors/commons/queue_processor.dart';
import 'package:flutter_flavorizr/src/processors/commons/unzip_file_processor.dart';
import 'package:flutter_flavorizr/src/processors/darwin/darwin_schemas_processor.dart';
import 'package:flutter_flavorizr/src/processors/darwin/podfile_processor.dart';
import 'package:flutter_flavorizr/src/processors/flutter/flutter_flavors_processor.dart';
import 'package:flutter_flavorizr/src/processors/google/firebase/firebase_processor.dart';
import 'package:flutter_flavorizr/src/processors/huawei/agconnect/agconnect_processor.dart';
import 'package:flutter_flavorizr/src/processors/ide/ide_processor.dart';
import 'package:flutter_flavorizr/src/processors/ios/build_configuration/ios_build_configurations_targets_processor.dart';
import 'package:flutter_flavorizr/src/processors/ios/dummy_assets/ios_dummy_assets_targets_processor.dart';
import 'package:flutter_flavorizr/src/processors/ios/icons/ios_icons_processor.dart';
import 'package:flutter_flavorizr/src/processors/ios/ios_plist_processor.dart';
import 'package:flutter_flavorizr/src/processors/ios/launch_screen/ios_targets_launchscreen_file_processor.dart';
import 'package:flutter_flavorizr/src/processors/ios/xcconfig/ios_xcconfig_targets_file_processor.dart';
import 'package:flutter_flavorizr/src/processors/macos/build_configuration/macos_build_configurations_targets_processor.dart';
import 'package:flutter_flavorizr/src/processors/macos/configs/macos_configs_targets_file_processor.dart';
import 'package:flutter_flavorizr/src/processors/macos/dummy_assets/macos_dummy_assets_targets_processor.dart';
import 'package:flutter_flavorizr/src/processors/macos/icons/macos_icons_processor.dart';
import 'package:flutter_flavorizr/src/processors/macos/macos_plist_processor.dart';
import 'package:flutter_flavorizr/src/processors/macos/xcconfig/macos_xcconfig_targets_file_processor.dart';
import 'package:flutter_flavorizr/src/utils/constants.dart';
import 'package:mason_logger/mason_logger.dart';

class Processor extends AbstractProcessor<void> {
  final Map<String, AbstractProcessor<void> Function()> _availableProcessors;
  final bool force;

  static const List<String> defaultInstructionSet = [
    // Prepare
    'assets:download',
    'assets:extract',

    // Android
    'android:androidManifest',
    'android:flavorizrGradle',
    'android:buildGradle',
    'android:dummyAssets',
    'android:icons',

    // Flutter
    'flutter:flavors',
    'flutter:app',
    'flutter:pages',
    'flutter:main',

    // iOS
    'ios:podfile',
    'ios:xcconfig',
    'ios:buildTargets',
    'ios:schema',
    'ios:dummyAssets',
    'ios:icons',
    'ios:plist',
    'ios:launchScreen',

    // macOS
    'macos:podfile',
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

  Processor(
    super.config, {
    this.force = false,
    required super.logger,
  }) : _availableProcessors = _initAvailableProcessors(config, logger: logger);

  @override
  void execute() async {
    final instructions = List.from(config.instructions ?? defaultInstructionSet)
      ..removeWhere((instruction) =>
          !config.androidFlavorsAvailable && instruction.startsWith('android'))
      ..removeWhere((instruction) =>
          !config.iosFlavorsAvailable && instruction.startsWith('ios'))
      ..removeWhere((instruction) =>
          !config.macosFlavorsAvailable && instruction.startsWith('macos'));

    logger.info('Flavorization process started');

    if (!force) {
      logger.info('The following instructions will be executed:');
      for (String instruction in instructions) {
        logger.info(' - $instruction');
      }
    }

    final confirm =
        force || logger.confirm('Do you want to proceed?', defaultValue: true);

    if (confirm) {
      for (String instruction in instructions) {
        final progress = logger.progress(instruction);

        progress.update('[$instruction] Executing');

        AbstractProcessor? processor =
            _availableProcessors[instruction]?.call();
        if (processor == null) {
          progress.fail('[$instruction] An error has occurred');
        }

        await processor?.execute();
        progress.complete('[$instruction] Completed');
      }

      logger.success('Flavorization process finished');
    } else {
      logger.info('Flavorization process cancelled');
    }
  }

  static Map<String, AbstractProcessor<void> Function()>
      _initAvailableProcessors(
    Flavorizr flavorizr, {
    required Logger logger,
  }) {
    return {
      // Commons
      'assets:download': () => DownloadFileProcessor(
            K.assetsZipPath,
            config: flavorizr,
            logger: logger,
          ),
      'assets:extract': () => UnzipFileProcessor(
            K.assetsZipPath,
            K.tempPath,
            config: flavorizr,
            logger: logger,
          ),
      'assets:clean': () => QueueProcessor(
            [
              DeleteFileProcessor(
                K.assetsZipPath,
                config: flavorizr,
                logger: logger,
              ),
              DeleteFileProcessor(
                K.tempPath,
                config: flavorizr,
                logger: logger,
              ),
            ],
            config: flavorizr,
            logger: logger,
          ),

      // Android
      'android:androidManifest': () => ExistingFileStringProcessor(
            K.androidManifestPath,
            AndroidManifestProcessor(config: flavorizr, logger: logger),
            config: flavorizr,
            logger: logger,
          ),
      'android:flavorizrGradle': () => AndroidFlavorizrGradleProcessor(
            [
              K.androidBuildLegacyPath,
              K.androidBuildKotlinPath,
            ],
            [
              K.androidFlavorizrLegacyPath,
              K.androidFlavorizrKotlinPath,
            ],
            [
              AndroidFlavorizrLegacyProcessor(
                config: flavorizr,
                logger: logger,
              ),
              AndroidFlavorizrKotlinProcessor(
                config: flavorizr,
                logger: logger,
              )
            ],
            config: flavorizr,
            logger: logger,
          ),
      'android:buildGradle': () => ApplyProcessorByExistingFileProcessor(
            [
              K.androidBuildLegacyPath,
              K.androidBuildKotlinPath,
            ],
            [
              AndroidBuildLegacyProcessor(
                K.androidFlavorizrLegacyName,
                config: flavorizr,
                logger: logger,
              ),
              AndroidBuildKotlinProcessor(
                K.androidFlavorizrKotlinName,
                config: flavorizr,
                logger: logger,
              ),
            ],
            config: flavorizr,
            logger: logger,
          ),
      'android:dummyAssets': () => AndroidDummyAssetsProcessor(
            K.tempAndroidResPath,
            K.androidSrcPath,
            config: flavorizr,
            logger: logger,
          ),
      'android:icons': () => AndroidIconsProcessor(
            config: flavorizr,
            logger: logger,
          ),

      //Flutter
      'flutter:flavors': () => NewFileStringProcessor(
            K.flutterFlavorPath,
            FlutterFlavorsProcessor(
              config: flavorizr,
              logger: logger,
            ),
            config: flavorizr,
            logger: logger,
          ),
      'flutter:app': () => CopyFileProcessor(
            K.tempFlutterAppPath,
            K.flutterAppPath,
            config: flavorizr,
            logger: logger,
          ),
      'flutter:pages': () => CopyFolderProcessor(
            K.tempFlutterPagesPath,
            K.flutterPagesPath,
            config: flavorizr,
            logger: logger,
          ),
      'flutter:main': () => CopyFileProcessor(
            K.tempFlutterMainPath,
            K.flutterMainPath,
            config: flavorizr,
            logger: logger,
          ),

      //iOS
      'ios:podfile': () => DynamicFileStringProcessor(
            K.iOSPodfilePath,
            PodfileProcessor(
              flavors: flavorizr.iosFlavors.keys.toList(growable: false),
              config: flavorizr,
              logger: logger,
            ),
            config: flavorizr,
            logger: logger,
          ),
      'ios:xcconfig': () => IOSXCConfigTargetsFileProcessor(
            'ruby',
            K.tempDarwinAddFileScriptPath,
            K.iOSRunnerProjectPath,
            K.iOSFlutterPath,
            config: flavorizr,
            logger: logger,
          ),
      'ios:buildTargets': () => IOSBuildConfigurationsTargetsProcessor(
            'ruby',
            K.tempDarwinAddBuildConfigurationScriptPath,
            K.iOSRunnerProjectPath,
            K.iOSFlutterPath,
            config: flavorizr,
            logger: logger,
          ),
      'ios:schema': () => DarwinSchemasProcessor(
            'ruby',
            K.tempDarwinCreateSchemeScriptPath,
            K.iOSRunnerProjectPath,
            config: flavorizr,
            logger: logger,
          ),
      'ios:dummyAssets': () => IOSDummyAssetsTargetsProcessor(
            K.tempiOSAssetsPath,
            K.iOSAssetsPath,
            config: flavorizr,
            logger: logger,
          ),
      'ios:icons': () => IOSIconsProcessor(
            config: flavorizr,
            logger: logger,
          ),
      'ios:plist': () => ExistingFileStringProcessor(
            K.iOSPListPath,
            IOSPListProcessor(
              config: flavorizr,
              logger: logger,
            ),
            config: flavorizr,
            logger: logger,
          ),
      'ios:launchScreen': () => IOSTargetsLaunchScreenFileProcessor(
            'ruby',
            K.tempDarwinAddFileScriptPath,
            K.iOSRunnerProjectPath,
            K.tempiOSLaunchScreenPath,
            K.iOSRunnerPath,
            config: flavorizr,
            logger: logger,
          ),

      // MacOS
      'macos:podfile': () => DynamicFileStringProcessor(
            K.macOSPodfilePath,
            PodfileProcessor(
              flavors: flavorizr.macosFlavors.keys.toList(growable: false),
              config: flavorizr,
              logger: logger,
            ),
            config: flavorizr,
            logger: logger,
          ),
      'macos:xcconfig': () => MacOSXCConfigTargetsFileProcessor(
            K.macOSFlutterPath,
            config: flavorizr,
            logger: logger,
          ),
      'macos:configs': () => MacOSConfigsTargetsFileProcessor(
            'ruby',
            K.tempDarwinAddFileScriptPath,
            K.macOSRunnerProjectPath,
            K.macOSConfigsPath,
            config: flavorizr,
            logger: logger,
          ),
      'macos:buildTargets': () => MacOSBuildConfigurationsTargetsProcessor(
            'ruby',
            K.tempDarwinAddBuildConfigurationScriptPath,
            K.macOSRunnerProjectPath,
            K.macOSConfigsPath,
            config: flavorizr,
            logger: logger,
          ),
      'macos:schema': () => DarwinSchemasProcessor(
            'ruby',
            K.tempDarwinCreateSchemeScriptPath,
            K.macOSRunnerProjectPath,
            config: flavorizr,
            logger: logger,
          ),
      'macos:dummyAssets': () => MacOSDummyAssetsTargetsProcessor(
            K.tempMacOSAssetsPath,
            K.macOSAssetsPath,
            config: flavorizr,
            logger: logger,
          ),
      'macos:icons': () => MacOSIconsProcessor(
            config: flavorizr,
            logger: logger,
          ),
      'macos:plist': () => ExistingFileStringProcessor(
            K.macOSPlistPath,
            MacOSPListProcessor(
              config: flavorizr,
              logger: logger,
            ),
            config: flavorizr,
            logger: logger,
          ),

      // Google
      'google:firebase': () => FirebaseProcessor(
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
            logger: logger,
          ),

      // Huawei
      'huawei:agconnect': () => AGConnectProcessor(
            destination: K.androidSrcPath,
            config: flavorizr,
            logger: logger,
          ),

      // IDE
      'ide:config': () => IDEProcessor(
            config: flavorizr,
            logger: logger,
          ),
    };
  }
}
