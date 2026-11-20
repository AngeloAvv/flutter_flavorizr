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

import 'package:flutter_flavorizr/src/exception/unknown_processor_exception.dart';
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
import 'package:flutter_flavorizr/src/processors/commons/dynamic_file_string_processor.dart';
import 'package:flutter_flavorizr/src/processors/commons/existing_file_string_processor.dart';
import 'package:flutter_flavorizr/src/processors/darwin/podfile_processor.dart';
import 'package:flutter_flavorizr/src/processors/ide/ide_processor.dart';
import 'package:flutter_flavorizr/src/processors/ios/ios_plist_processor.dart';
import 'package:flutter_flavorizr/src/processors/linux/linux_cmake_lists_processor.dart';
import 'package:flutter_flavorizr/src/processors/linux/linux_my_application_processor.dart';
import 'package:flutter_flavorizr/src/processors/linux/linux_runner_cmake_lists_processor.dart';
import 'package:flutter_flavorizr/src/processors/macos/macos_plist_processor.dart';
import 'package:flutter_flavorizr/src/processors/windows/icons/windows_icons_processor.dart';
import 'package:flutter_flavorizr/src/processors/windows/windows_dummy_assets_processor.dart';
import 'package:flutter_flavorizr/src/processors/windows/windows_main_cpp_template_processor.dart';
import 'package:flutter_flavorizr/src/processors/windows/windows_runner_cmake_lists_processor.dart';
import 'package:flutter_flavorizr/src/processors/windows/windows_runner_rc_template_processor.dart';
import 'package:flutter_flavorizr/src/utils/constants.dart';
import 'package:mason_logger/mason_logger.dart';

class Processor extends AbstractProcessor<void> {
  final Map<String, AbstractProcessor<void> Function()> _availableProcessors;
  final bool force;

  /// What to run instead of [defaultInstructionSet].
  final List<String>? instructions;

  static const List<String> defaultInstructionSet = [
    // Android
    'android:androidManifest',
    'android:flavorizrGradle',
    'android:buildGradle',
    'android:dummyAssets',
    'android:icons',

    // Flutter. The starting files of a new app (`flutter:app`, `flutter:pages`
    // and `flutter:main`) are not part of it: see the `flutter:scaffold`
    // recipe.
    'flutter:flavors',

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

    // Linux
    'linux:cmake',
    'linux:runnerCmake',
    'linux:myApplication',

    // Windows
    'windows:mainCppTemplate',
    'windows:runnerRcTemplate',
    'windows:cmake',
    'windows:dummyAssets',
    'windows:icons',

    // IDE
    'ide:config',
  ];

  Processor(
    super.config, {
    this.force = false,
    this.instructions,
    required super.logger,
  }) : _availableProcessors = _initAvailableProcessors(config, logger: logger);

  /// Resolves the configured (or default) instruction set, dropping any
  /// platform-specific instructions for platforms with no flavors defined.
  List<String> resolveInstructions() =>
      List<String>.from(instructions ?? defaultInstructionSet)
        ..removeWhere(
          (instruction) =>
              !config.androidFlavorsAvailable &&
              instruction.startsWith('android'),
        )
        ..removeWhere(
          (instruction) =>
              !config.iosFlavorsAvailable && instruction.startsWith('ios'),
        )
        ..removeWhere(
          (instruction) =>
              !config.macosFlavorsAvailable && instruction.startsWith('macos'),
        )
        ..removeWhere(
          (instruction) =>
              !config.linuxFlavorsAvailable && instruction.startsWith('linux'),
        )
        ..removeWhere(
          (instruction) =>
              !config.windowsFlavorsAvailable &&
              instruction.startsWith('windows'),
        );

  @override
  Future<void> execute() async {
    final instructions = resolveInstructions();

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
        await executeInstruction(instruction);
      }

      logger.success('Flavorization process finished');
    } else {
      logger.info('Flavorization process cancelled');
    }
  }

  /// Runs the single [instruction], which aborts the whole run when it fails.
  Future<void> executeInstruction(String instruction) async {
    final progress = logger.progress(instruction);

    progress.update('[$instruction] Executing');

    try {
      await runInstruction(instruction);
    } on Object {
      // The first failure aborts the run: nothing is executed after it.
      progress.fail('[$instruction] An error has occurred');
      rethrow;
    }

    progress.complete('[$instruction] Completed');
  }

  /// Runs the single [instruction] and shows nothing about it: whoever calls
  /// this is the one that shows the step.
  Future<void> runInstruction(String instruction) async {
    final create = _availableProcessors[instruction];
    if (create == null) {
      throw UnknownProcessorException(instruction);
    }

    await create().execute();
  }

  static Map<String, AbstractProcessor<void> Function()>
  _initAvailableProcessors(
    FlavorizrConfig flavorizr, {
    required Logger logger,
  }) {
    return {
      // Android
      'android:androidManifest': () => ExistingFileStringProcessor(
        K.androidManifestPath,
        AndroidManifestProcessor(config: flavorizr, logger: logger),
        config: flavorizr,
        logger: logger,
      ),
      'android:flavorizrGradle': () => AndroidFlavorizrGradleProcessor(
        [K.androidBuildLegacyPath, K.androidBuildKotlinPath],
        [K.androidFlavorizrLegacyPath, K.androidFlavorizrKotlinPath],
        [
          AndroidFlavorizrLegacyProcessor(config: flavorizr, logger: logger),
          AndroidFlavorizrKotlinProcessor(config: flavorizr, logger: logger),
        ],
        config: flavorizr,
        logger: logger,
      ),
      'android:buildGradle': () => ApplyProcessorByExistingFileProcessor(
        [K.androidBuildLegacyPath, K.androidBuildKotlinPath],
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
      'android:dummyAssets': () =>
          AndroidDummyAssetsProcessor(config: flavorizr, logger: logger),
      'android:icons': () =>
          AndroidIconsProcessor(config: flavorizr, logger: logger),

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
      'ios:plist': () => ExistingFileStringProcessor(
        K.iOSPListPath,
        IOSPListProcessor(config: flavorizr, logger: logger),
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
      'macos:plist': () => ExistingFileStringProcessor(
        K.macOSPlistPath,
        MacOSPListProcessor(config: flavorizr, logger: logger),
        config: flavorizr,
        logger: logger,
      ),

      // Linux
      'linux:cmake': () => ExistingFileStringProcessor(
        K.linuxCMakeListsPath,
        LinuxCMakeListsProcessor(config: flavorizr, logger: logger),
        config: flavorizr,
        logger: logger,
      ),
      'linux:runnerCmake': () => ExistingFileStringProcessor(
        K.linuxRunnerCMakeListsPath,
        LinuxRunnerCMakeListsProcessor(config: flavorizr, logger: logger),
        config: flavorizr,
        logger: logger,
      ),
      'linux:myApplication': () => ExistingFileStringProcessor(
        K.linuxMyApplicationPath,
        LinuxMyApplicationProcessor(config: flavorizr, logger: logger),
        config: flavorizr,
        logger: logger,
      ),

      // Windows
      'windows:mainCppTemplate': () => WindowsMainCppTemplateProcessor(
        K.windowsMainCppPath,
        K.windowsMainCppTemplatePath,
        config: flavorizr,
        logger: logger,
      ),
      'windows:runnerRcTemplate': () => WindowsRunnerRcTemplateProcessor(
        K.windowsRunnerRcPath,
        K.windowsRunnerRcTemplatePath,
        config: flavorizr,
        logger: logger,
      ),
      'windows:cmake': () => ExistingFileStringProcessor(
        K.windowsRunnerCMakeListsPath,
        WindowsRunnerCMakeListsProcessor(config: flavorizr, logger: logger),
        config: flavorizr,
        logger: logger,
      ),
      'windows:dummyAssets': () =>
          WindowsDummyAssetsProcessor(config: flavorizr, logger: logger),
      'windows:icons': () =>
          WindowsIconsProcessor(config: flavorizr, logger: logger),

      // IDE
      'ide:config': () => IDEProcessor(config: flavorizr, logger: logger),
    };
  }
}
