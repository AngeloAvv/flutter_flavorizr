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

import 'dart:convert';

import 'package:flutter_flavorizr/src/engine/artifact.dart';
import 'package:flutter_flavorizr/src/engine/flavorizr_processor.dart';
import 'package:flutter_flavorizr/src/engine/ownership.dart';
import 'package:flutter_flavorizr/src/engine/processors/android/android_build_gradle_editor.dart';
import 'package:flutter_flavorizr/src/engine/processors/android/android_build_gradle_patch_processor.dart';
import 'package:flutter_flavorizr/src/engine/processors/android/android_dummy_assets_processor.dart';
import 'package:flutter_flavorizr/src/engine/processors/android/android_icons_processor.dart';
import 'package:flutter_flavorizr/src/engine/processors/android/android_manifest_editor.dart';
import 'package:flutter_flavorizr/src/engine/processors/android/android_manifest_patch_processor.dart';
import 'package:flutter_flavorizr/src/engine/processors/android/flavorizr_gradle_processor.dart';
import 'package:flutter_flavorizr/src/engine/processors/darwin/build_settings_owned_content.dart';
import 'package:flutter_flavorizr/src/engine/processors/darwin/build_targets_processors.dart';
import 'package:flutter_flavorizr/src/engine/processors/darwin/darwin_dummy_assets_processors.dart';
import 'package:flutter_flavorizr/src/engine/processors/darwin/darwin_icons_processors.dart';
import 'package:flutter_flavorizr/src/engine/processors/darwin/info_plist_editor.dart';
import 'package:flutter_flavorizr/src/engine/processors/darwin/info_plist_patch_processor.dart';
import 'package:flutter_flavorizr/src/engine/processors/darwin/launch_screen_processor.dart';
import 'package:flutter_flavorizr/src/engine/processors/darwin/podfile_editor.dart';
import 'package:flutter_flavorizr/src/engine/processors/darwin/podfile_patch_processor.dart';
import 'package:flutter_flavorizr/src/engine/processors/darwin/scheme_editor.dart';
import 'package:flutter_flavorizr/src/engine/processors/darwin/scheme_processors.dart';
import 'package:flutter_flavorizr/src/engine/processors/darwin/xcconfig_processors.dart';
import 'package:flutter_flavorizr/src/engine/processors/darwin/xcconfig_references.dart';
import 'package:flutter_flavorizr/src/engine/processors/google/firebase_processors.dart';
import 'package:flutter_flavorizr/src/engine/processors/huawei/agconnect_processor.dart';
import 'package:flutter_flavorizr/src/engine/processors/ide/ide_config_processor.dart';
import 'package:flutter_flavorizr/src/engine/processors/linux/linux_cmake_lists_editor.dart';
import 'package:flutter_flavorizr/src/engine/processors/linux/linux_cmake_lists_patch_processor.dart';
import 'package:flutter_flavorizr/src/engine/processors/linux/linux_my_application_editor.dart';
import 'package:flutter_flavorizr/src/engine/processors/linux/linux_my_application_patch_processor.dart';
import 'package:flutter_flavorizr/src/engine/processors/linux/linux_runner_cmake_lists_editor.dart';
import 'package:flutter_flavorizr/src/engine/processors/linux/linux_runner_cmake_lists_patch_processor.dart';
import 'package:flutter_flavorizr/src/engine/processors/flutter/flutter_processors.dart';
import 'package:flutter_flavorizr/src/engine/processors/windows/windows_icons_processor.dart';
import 'package:flutter_flavorizr/src/engine/processors/windows/windows_main_cpp_template_processor.dart';
import 'package:flutter_flavorizr/src/engine/processors/windows/windows_runner_cmake_lists_editor.dart';
import 'package:flutter_flavorizr/src/engine/processors/windows/windows_runner_cmake_lists_patch_processor.dart';
import 'package:flutter_flavorizr/src/engine/processors/windows/windows_runner_rc_template_processor.dart';
import 'package:flutter_flavorizr/src/engine/reconcile/created_files.dart';
import 'package:flutter_flavorizr/src/engine/recipe/built_in_recipes.dart';
import 'package:flutter_flavorizr/src/engine/recipe/recipe_catalog.dart';
import 'package:flutter_flavorizr/src/engine/resource.dart';
import 'package:flutter_flavorizr/src/engine/resource_key.dart';
import 'package:flutter_flavorizr/src/engine/resources/xcodeproj_resource.dart';
import 'package:flutter_flavorizr/src/engine/shadow/file_digest.dart';
import 'package:flutter_flavorizr/src/exception/duplicate_processor_exception.dart';
import 'package:flutter_flavorizr/src/exception/invalid_processor_registration_exception.dart';
import 'package:flutter_flavorizr/src/utils/constants.dart';

/// A processor that runs on the engine, with what the CLI has to know about it
/// and the processor cannot tell.
final class EngineProcessor {
  /// The processor.
  final FlavorizrProcessor processor;

  /// The files and folders of the project it reads or writes, relative to it.
  /// They are what its shadow workspace is made of: nothing outside of them is
  /// copied, diffed or written back.
  final Set<String> paths;

  /// How to read the part of a patched file the processor owns, by path of the
  /// file. It is what the lock hashes, so that whatever else the user edits is
  /// never drift. A file that is not here is hashed whole.
  ///
  /// A path may have a `*` in the name of the file, which stands for any
  /// characters but `/`: it is for the files whose names are the flavors', such
  /// as the schemes (`ios/Runner.xcodeproj/xcshareddata/xcschemes/*.xcscheme`).
  final Map<String, String Function(String source)> ownedContent;

  /// How to read what a patched file holds that is neither owned by the
  /// processor nor added by the tools around it, by path of the file (with the
  /// same `*`). It is for the files the processor **creates**, and is what tells
  /// one it made, and that the user did not edit, from one that is theirs when
  /// its flavor is dropped: see `recordCreated`. A file that is not here is
  /// never deleted with its flavor.
  final Map<String, String Function(String source)> foreignContent;

  /// Registers [processor], which works on [paths].
  const EngineProcessor(
    this.processor, {
    required this.paths,
    this.ownedContent = const {},
    this.foreignContent = const {},
  });
}

/// The part of the iOS `project.pbxproj` the lock hashes: what the processors
/// that own objects in it say they own.
///
/// The references to the storyboards of the launch screens are in it only when
/// the project has some, so that the hash of a project without them is the one
/// it was before they existed.
String iosProjectOwnedContent(String source) {
  final launchScreens = launchScreenReferencesOwnedContent(source);

  return [
    xcconfigReferencesOwnedContent(source),
    if (launchScreens.isNotEmpty) launchScreens,
    buildSettingsOwnedContent(source),
    firebaseOwnedContent(source, 'ios'),
  ].join('\n');
}

/// A shared resource of the engine, with what the CLI has to know about it and
/// the resource cannot tell.
final class EngineResource {
  /// The resource.
  final Resource<Object?> resource;

  /// The files and folders of the project it reads or writes, relative to it.
  /// They join the shadow workspace of every run that has a processor that
  /// requires the resource, so that a processor needs no path of it.
  final Set<String> paths;

  /// How to read the part of a patched file that the processors sharing the
  /// resource own, by path of the file, like [EngineProcessor.ownedContent].
  /// It is what the lock hashes, so that an edit of the rest of the file, by
  /// Xcode, CocoaPods or Flutter, is never drift. A file that is not here is
  /// hashed whole.
  final Map<String, String Function(String source)> ownedContent;

  /// Registers [resource], which works on [paths].
  const EngineResource(
    this.resource, {
    this.paths = const {},
    this.ownedContent = const {},
  });
}

/// Every processor flavorizr knows.
///
/// Every processor runs on the engine, which previews its changes in a shadow
/// workspace, checks them against the lock and writes them back atomically.
/// A processor is added to [ProcessorRegistry.standard], and the CLI needs no
/// other change. Processors of the user are added with [withProcessors].
class ProcessorRegistry {
  final Map<String, EngineProcessor> _engine;
  final Set<String> _overridden = {};

  /// The ids of the processors of flavorizr: the only ones an override can
  /// replace, whatever the registry has been extended with.
  Set<String> _builtIn = const {};
  final Map<ResourceKey<Object?>, EngineResource> _resources;

  /// Creates a registry of [engine] processors and the shared [resources] they
  /// may require.
  ProcessorRegistry({
    Iterable<EngineProcessor> engine = const [],
    Iterable<EngineResource> resources = const [],
  }) : _resources = {for (final entry in resources) entry.resource.key: entry},
       _engine = {for (final entry in engine) entry.processor.id: entry} {
    _builtIn = {..._engine.keys};
  }

  /// The registry of this version: every processor of flavorizr.
  factory ProcessorRegistry.standard() => ProcessorRegistry(
    engine: [
      EngineProcessor(
        const AndroidManifestPatchProcessor(),
        paths: {K.androidManifestPath},
        ownedContent: {
          K.androidManifestPath: AndroidManifestEditor.ownedContent,
        },
      ),
      EngineProcessor(
        const FlavorizrGradleProcessor(),
        paths: {K.androidFlavorizrLegacyPath, K.androidFlavorizrKotlinPath},
      ),
      EngineProcessor(
        const AndroidBuildGradlePatchProcessor(),
        paths: {K.androidBuildLegacyPath, K.androidBuildKotlinPath},
        ownedContent: {
          K.androidBuildLegacyPath: AndroidBuildGradleEditor.ownedContent,
          K.androidBuildKotlinPath: AndroidBuildGradleEditor.ownedContent,
        },
      ),
      // The placeholder icons of 2.x are not made anymore, but the id stays.
      const EngineProcessor(AndroidDummyAssetsProcessor(), paths: {}),
      const EngineProcessor(
        AndroidIconsProcessor(),
        paths: {'android/app/src'},
      ),
      EngineProcessor(const IosXcconfigProcessor(), paths: {K.iOSFlutterPath}),
      EngineProcessor(
        const MacosXcconfigProcessor(),
        paths: {K.macOSFlutterPath},
      ),
      EngineProcessor(
        const MacosConfigsProcessor(),
        paths: {K.macOSConfigsPath},
      ),
      // The project is read, not written: the processor works in the folder of
      // the project the resource brings, and the schemes in it are what it owns.
      EngineProcessor(
        const IosSchemaProcessor(),
        paths: const {},
        ownedContent: {
          '${XcodeprojResource.iosProject}/xcshareddata/xcschemes/*.xcscheme':
              SchemeEditor.ownedContent,
        },
        foreignContent: {
          '${XcodeprojResource.iosProject}/xcshareddata/xcschemes/*.xcscheme':
              SchemeEditor.foreignContent,
        },
      ),
      EngineProcessor(
        const MacosSchemaProcessor(),
        paths: const {},
        ownedContent: {
          '${XcodeprojResource.macosProject}/xcshareddata/xcschemes/*.xcscheme':
              SchemeEditor.ownedContent,
        },
        foreignContent: {
          '${XcodeprojResource.macosProject}/xcshareddata/xcschemes/*.xcscheme':
              SchemeEditor.foreignContent,
        },
      ),
      // They work on the project, which the shared resource brings to the
      // shadow workspace, and own the build settings of the flavors in it.
      const EngineProcessor(IosBuildTargetsProcessor(), paths: {}),
      const EngineProcessor(MacosBuildTargetsProcessor(), paths: {}),
      EngineProcessor(
        const IosInfoPlistPatchProcessor(),
        paths: {K.iOSPListPath},
        ownedContent: {K.iOSPListPath: InfoPlistEditor.iosOwnedContent},
      ),
      // The appiconsets of the flavors, in the asset catalog of the app. The
      // placeholders of 2.x are not made anymore, but the ids stay.
      const EngineProcessor(IosDummyAssetsProcessor(), paths: {}),
      const EngineProcessor(MacosDummyAssetsProcessor(), paths: {}),
      EngineProcessor(const IosIconsProcessor(), paths: {K.iOSAssetsPath}),
      EngineProcessor(const MacosIconsProcessor(), paths: {K.macOSAssetsPath}),
      // The storyboards and the launch images of the flavors, in the asset
      // catalog of the app, and their references in the project.
      EngineProcessor(
        const IosLaunchScreenProcessor(),
        paths: {K.iOSRunnerPath},
      ),
      EngineProcessor(
        const MacosInfoPlistPatchProcessor(),
        paths: {K.macOSPlistPath},
        ownedContent: {K.macOSPlistPath: InfoPlistEditor.macosOwnedContent},
      ),
      EngineProcessor(
        const LinuxCMakeListsPatchProcessor(),
        paths: {K.linuxCMakeListsPath},
        ownedContent: {
          K.linuxCMakeListsPath: LinuxCMakeListsEditor.ownedContent,
        },
      ),
      EngineProcessor(
        const LinuxRunnerCMakeListsPatchProcessor(),
        paths: {K.linuxRunnerCMakeListsPath},
        ownedContent: {
          K.linuxRunnerCMakeListsPath: LinuxRunnerCMakeListsEditor.ownedContent,
        },
      ),
      EngineProcessor(
        const LinuxMyApplicationPatchProcessor(),
        paths: {K.linuxMyApplicationPath},
        ownedContent: {
          K.linuxMyApplicationPath: LinuxMyApplicationEditor.ownedContent,
        },
      ),
      // The templates are what these two write. The files they are made from,
      // `main.cpp` and `Runner.rc`, are the user's: they are read from the
      // project and never copied, diffed or written back.
      EngineProcessor(
        const WindowsMainCppTemplateProcessor(),
        paths: {K.windowsMainCppTemplatePath},
      ),
      EngineProcessor(
        const WindowsRunnerRcTemplateProcessor(),
        paths: {K.windowsRunnerRcTemplatePath},
      ),
      EngineProcessor(
        const WindowsRunnerCMakeListsPatchProcessor(),
        paths: {K.windowsRunnerCMakeListsPath},
        ownedContent: {
          K.windowsRunnerCMakeListsPath:
              WindowsRunnerCMakeListsEditor.ownedContent,
        },
      ),
      // The `.ico` of the flavors, next to the icon of the project. The
      // placeholders of 2.x are not made anymore, but the ids stay.
      const EngineProcessor(WindowsDummyAssetsProcessor(), paths: {}),
      EngineProcessor(
        const WindowsIconsProcessor(),
        paths: {K.windowsIconsPath},
      ),
      EngineProcessor(
        const IosPodfilePatchProcessor(),
        paths: {K.iOSPodfilePath},
        ownedContent: {K.iOSPodfilePath: PodfileEditor.ownedContent},
      ),
      EngineProcessor(
        const MacosPodfilePatchProcessor(),
        paths: {K.macOSPodfilePath},
        ownedContent: {K.macOSPodfilePath: PodfileEditor.ownedContent},
      ),
      EngineProcessor(
        const FlutterFlavorsProcessor(),
        paths: {K.flutterFlavorsGeneratedPath, K.flutterFlavorPath},
      ),
      EngineProcessor(
        const FlutterPagesProcessor(),
        paths: {K.flutterMainPagePath},
      ),
      EngineProcessor(const FlutterAppProcessor(), paths: {K.flutterAppPath}),
      EngineProcessor(const FlutterMainProcessor(), paths: {K.flutterMainPath}),
      // The Firebase configuration of the flavors: the copies are local, the
      // build phase of the Apple projects is owned.
      EngineProcessor(
        const AndroidFirebaseProcessor(),
        paths: {K.androidSrcPath},
      ),
      EngineProcessor(
        const IosFirebaseProcessor(),
        paths: {K.iOSRunnerPath, K.iOSFirebaseScriptPath},
      ),
      EngineProcessor(
        const MacosFirebaseProcessor(),
        paths: {K.macOSRunnerPath, K.macOSFirebaseScriptPath},
      ),
      // The AppGallery Connect configuration of the flavors: the copies are
      // local.
      EngineProcessor(const AGConnectProcessor(), paths: {K.androidSrcPath}),
      // The run configurations of the IDEs are local: the IDEs write to them,
      // and git ignores `.idea/`.
      EngineProcessor(
        const IdeConfigProcessor(),
        paths: {K.ideaLaunchpath, K.vsCodeLaunchPath},
      ),
    ],
    resources: [
      // The part of the projects the lock hashes is the one the processors
      // above own: the references to the xcconfigs of the flavors, the build
      // settings of their configurations and the Firebase build phase. What
      // else Xcode or Flutter change is never drift.
      EngineResource(
        XcodeprojResource.ios(),
        paths: const {XcodeprojResource.iosProject},
        ownedContent: {
          XcodeprojResource.iosArtifact.path: iosProjectOwnedContent,
        },
      ),
      EngineResource(
        XcodeprojResource.macos(),
        paths: const {XcodeprojResource.macosProject},
        ownedContent: {
          XcodeprojResource.macosArtifact.path: (source) => [
            xcconfigReferencesOwnedContent(source),
            buildSettingsOwnedContent(source),
            firebaseOwnedContent(source, 'macos'),
          ].join('\n'),
        },
      ),
    ],
  );

  /// This registry with the processors of the user, which run on the engine
  /// and declare the paths they work on and the part of a patched file they
  /// own themselves.
  ///
  /// The [processors] are new ones: their ids are not taken, and are not in a
  /// namespace of flavorizr (see [reservedNamespaces]). The [overrides] replace
  /// a processor of flavorizr, the one that has their id: they take its place
  /// in the recipes and in the dependencies of the other processors, and work
  /// on the paths of the processor they replace as well as their own.
  /// What an override patches in a file, it declares in [FlavorizrProcessor.ownedContent],
  /// which replaces the one of the processor for that file: otherwise the lock
  /// hashes the part the replaced processor owned, not what the override
  /// changes.
  ///
  /// Throws a [DuplicateProcessorException] when the id of a processor is
  /// already taken, by this registry or by another processor of the user, and
  /// an [InvalidProcessorRegistrationException] for one in a namespace of
  /// flavorizr, or an override of a processor flavorizr does not have.
  ProcessorRegistry withProcessors(
    Iterable<FlavorizrProcessor> processors, {
    Iterable<FlavorizrProcessor> overrides = const [],
  }) {
    // Read once: a lazy iterable may not give the same processors twice.
    final added = processors.toList(growable: false);
    final replaced = overrides.toList(growable: false);
    final builtIn = _builtIn;
    final taken = {...ids};

    for (final processor in added) {
      if (builtIn.contains(processor.id)) {
        throw DuplicateProcessorException(processor.id, builtIn: true);
      }
      if (reservedNamespaces.contains(processor.id.split(':').first)) {
        throw InvalidProcessorRegistrationException.reserved(processor.id);
      }
      if (!taken.add(processor.id)) {
        throw DuplicateProcessorException(processor.id);
      }
    }

    final replacing = <String>{};

    for (final processor in replaced) {
      if (!builtIn.contains(processor.id)) {
        throw InvalidProcessorRegistrationException.notBuiltIn(processor.id);
      }
      if (!replacing.add(processor.id)) {
        throw DuplicateProcessorException(processor.id);
      }
    }

    final engine = {..._engine};

    for (final processor in replaced) {
      final previous = _engine[processor.id];

      engine[processor.id] = EngineProcessor(
        processor,
        paths: {...?previous?.paths, ...processor.paths},
        ownedContent: {...?previous?.ownedContent, ...processor.ownedContent},
        foreignContent: {...?previous?.foreignContent},
      );
    }

    return ProcessorRegistry(
        engine: [
          ...engine.values,
          for (final processor in added)
            EngineProcessor(
              processor,
              paths: processor.paths,
              ownedContent: processor.ownedContent,
            ),
        ],
        resources: _resources.values,
      )
      .._overridden.addAll({..._overridden, ...replacing})
      .._builtIn = builtIn;
  }

  /// The ids of the processors of flavorizr that a processor of the user
  /// replaces.
  Set<String> get overriddenIds => Set.unmodifiable(_overridden);

  /// The processors, by id.
  Map<String, FlavorizrProcessor> get engineProcessors => {
    for (final entry in _engine.entries) entry.key: entry.value.processor,
  };

  /// The shared resources the processors may require.
  List<Resource<Object?>> get resources => [
    for (final entry in _resources.values) entry.resource,
  ];

  /// The ids of the processors a full run covers: the ones that the `all`
  /// recipe reaches.
  ///
  /// The lock records the flavors a run applied only when it is a full run. A
  /// processor that is not part of `all`, such as the ones of `flutter:scaffold`
  /// (a project is not expected to run them every time), must not stop a run of
  /// everything else from being one.
  Set<String> get fullRunIds => RecipeCatalog(
    processorIds: ids,
  ).resolve([allRecipeName]).processorIds.toSet();

  /// The id of every processor.
  Set<String> get ids => Set.unmodifiable(_engine.keys);

  /// The paths the shadow workspace of a run of [processors] is made of.
  ///
  /// They are the paths of the processors and the ones of the resources the
  /// processors require.
  Set<String> pathsOf(Iterable<FlavorizrProcessor> processors) => {
    for (final processor in processors) ...{
      ..._engine[processor.id]!.paths,
      for (final key in processor.requires) ...?_resources[key]?.paths,
    },
  };

  /// How to read what the file at [path] holds that is neither owned nor added
  /// by the tools around it, when a processor that creates it says so: see
  /// [EngineProcessor.foreignContent]. `null` for any other file.
  ForeignReader? foreignReader(String path) {
    for (final entry in _engine.values) {
      final reader = _readerOf(entry.foreignContent, Artifact.patched(path));

      if (reader != null) return reader;
    }

    return null;
  }

  /// Hashes the part of a file that [artifact] owns: what the lock records and
  /// compares with the disk.
  ///
  /// The owned part of a patched file is told by the processor or the shared
  /// resource that owns it, anything else is hashed whole. A byte order mark never matters.
  String hash(Artifact artifact, List<int> bytes) {
    if (artifact.ownership != Ownership.patched) return digestOf(bytes);

    final readers = [
      ..._engine.values.map((entry) => _readerOf(entry.ownedContent, artifact)),
      ..._resources.values.map(
        (entry) => _readerOf(entry.ownedContent, artifact),
      ),
    ].nonNulls.toList(growable: false);

    if (readers.isEmpty) return digestOf(bytes);

    final text = utf8.decode(bytes, allowMalformed: true);
    final source = text.startsWith('\ufeff') ? text.substring(1) : text;

    final parts = [for (final read in readers) read(source)];

    // Processors may own different parts of the same file: every part counts.
    // Each is framed by its length, so that where one ends and the next starts
    // is part of what is hashed. A file with one owner hashes its part as is.
    return digestOf(
      utf8.encode(
        parts.length == 1
            ? parts.single
            : [for (final part in parts) '${part.length}:$part'].join(),
      ),
    );
  }

  /// The reader of [artifact] among [readers], by path: the one of the exact
  /// path, or else the one of a pattern with a `*` that the path matches.
  static String Function(String source)? _readerOf(
    Map<String, String Function(String source)> readers,
    Artifact artifact,
  ) {
    final exact = readers[artifact.path];

    if (exact != null) return exact;

    for (final MapEntry(key: pattern, value: reader) in readers.entries) {
      if (!pattern.contains('*')) continue;

      final matcher = RegExp(
        '^${pattern.split('*').map(RegExp.escape).join('[^/]*')}\$',
      );

      if (matcher.hasMatch(artifact.path)) return reader;
    }

    return null;
  }
}
