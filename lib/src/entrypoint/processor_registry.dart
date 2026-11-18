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
import 'package:flutter_flavorizr/src/engine/processors/android/android_icons_processor.dart';
import 'package:flutter_flavorizr/src/engine/processors/android/android_manifest_editor.dart';
import 'package:flutter_flavorizr/src/engine/processors/android/android_manifest_patch_processor.dart';
import 'package:flutter_flavorizr/src/engine/processors/android/flavorizr_gradle_processor.dart';
import 'package:flutter_flavorizr/src/engine/processors/darwin/info_plist_editor.dart';
import 'package:flutter_flavorizr/src/engine/processors/darwin/info_plist_patch_processor.dart';
import 'package:flutter_flavorizr/src/engine/processors/darwin/podfile_editor.dart';
import 'package:flutter_flavorizr/src/engine/processors/darwin/podfile_patch_processor.dart';
import 'package:flutter_flavorizr/src/engine/processors/darwin/xcconfig_processors.dart';
import 'package:flutter_flavorizr/src/engine/processors/darwin/xcconfig_references.dart';
import 'package:flutter_flavorizr/src/engine/processors/linux/linux_cmake_lists_editor.dart';
import 'package:flutter_flavorizr/src/engine/processors/linux/linux_cmake_lists_patch_processor.dart';
import 'package:flutter_flavorizr/src/engine/processors/linux/linux_my_application_editor.dart';
import 'package:flutter_flavorizr/src/engine/processors/linux/linux_my_application_patch_processor.dart';
import 'package:flutter_flavorizr/src/engine/processors/linux/linux_runner_cmake_lists_editor.dart';
import 'package:flutter_flavorizr/src/engine/processors/linux/linux_runner_cmake_lists_patch_processor.dart';
import 'package:flutter_flavorizr/src/engine/processors/flutter/flutter_processors.dart';
import 'package:flutter_flavorizr/src/engine/processors/windows/windows_main_cpp_template_processor.dart';
import 'package:flutter_flavorizr/src/engine/processors/windows/windows_runner_cmake_lists_editor.dart';
import 'package:flutter_flavorizr/src/engine/processors/windows/windows_runner_cmake_lists_patch_processor.dart';
import 'package:flutter_flavorizr/src/engine/processors/windows/windows_runner_rc_template_processor.dart';
import 'package:flutter_flavorizr/src/engine/recipe/built_in_recipes.dart';
import 'package:flutter_flavorizr/src/engine/recipe/recipe_catalog.dart';
import 'package:flutter_flavorizr/src/engine/resource.dart';
import 'package:flutter_flavorizr/src/engine/resource_key.dart';
import 'package:flutter_flavorizr/src/engine/resources/xcodeproj_resource.dart';
import 'package:flutter_flavorizr/src/engine/shadow/file_digest.dart';
import 'package:flutter_flavorizr/src/processors/processor.dart';
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
  final Map<String, String Function(String source)> ownedContent;

  /// Registers [processor], which works on [paths].
  const EngineProcessor(
    this.processor, {
    required this.paths,
    this.ownedContent = const {},
  });
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

/// Every processor flavorizr knows, and where each one runs.
///
/// A processor either runs on the engine, which previews its changes in a
/// shadow workspace, checks them against the lock and writes them back
/// atomically, or it still is a 2.x one, which the legacy pipeline applies
/// straight to the project. Porting a processor moves it from the second kind
/// to the first: it is added to [ProcessorRegistry.standard], and the CLI needs
/// no other change. Processors of the user would be registered the same way.
class ProcessorRegistry {
  final Map<String, EngineProcessor> _engine;
  final Set<String> _legacyIds;
  final Map<ResourceKey<Object?>, EngineResource> _resources;

  /// Creates a registry of [engine] processors, the legacy processors named by
  /// [legacyIds] and the shared [resources] the engine processors may require.
  ProcessorRegistry({
    Iterable<EngineProcessor> engine = const [],
    Iterable<String> legacyIds = const [],
    Iterable<EngineResource> resources = const [],
  }) : _resources = {for (final entry in resources) entry.resource.key: entry},
       _engine = {for (final entry in engine) entry.processor.id: entry},
       _legacyIds = {
         for (final id in legacyIds)
           if (!engine.any((entry) => entry.processor.id == id)) id,
       };

  /// The registry of this version: the Android, Linux, Windows, Flutter,
  /// xcconfig, Podfile and Info.plist processors that were ported run on the
  /// engine, every other 2.x
  /// instruction on the legacy pipeline.
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
      EngineProcessor(
        const IosInfoPlistPatchProcessor(),
        paths: {K.iOSPListPath},
        ownedContent: {K.iOSPListPath: InfoPlistEditor.iosOwnedContent},
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
    ],
    resources: [
      // The part of the projects the lock hashes is the one the processors
      // above own: the references to the xcconfigs of the flavors. The 2.x
      // processors that run after the engine change the rest.
      EngineResource(
        XcodeprojResource.ios(),
        paths: const {XcodeprojResource.iosProject},
        ownedContent: {
          XcodeprojResource.iosArtifact.path: xcconfigReferencesOwnedContent,
        },
      ),
      EngineResource(
        XcodeprojResource.macos(),
        paths: const {XcodeprojResource.macosProject},
        ownedContent: {
          XcodeprojResource.macosArtifact.path: xcconfigReferencesOwnedContent,
        },
      ),
    ],
    legacyIds: Processor.defaultInstructionSet,
  );

  /// The processors that run on the engine, by id.
  Map<String, FlavorizrProcessor> get engineProcessors => {
    for (final entry in _engine.entries) entry.key: entry.value.processor,
  };

  /// The shared resources the processors that run on the engine may require.
  List<Resource<Object?>> get resources => [
    for (final entry in _resources.values) entry.resource,
  ];

  /// The ids of the processors that run on the engine.
  Set<String> get engineIds => Set.unmodifiable(_engine.keys);

  /// The ids of the processors a full run covers: the ones of the engine that
  /// the `all` recipe reaches.
  ///
  /// The lock records the flavors a run applied only when it is a full run. A
  /// processor that is not part of `all`, such as the ones of `flutter:scaffold`
  /// (a project is not expected to run them every time), must not stop a run of
  /// everything else from being one.
  Set<String> get fullRunIds => RecipeCatalog(
    processorIds: ids,
  ).resolve([allRecipeName]).processorIds.where(isEngine).toSet();

  /// The ids of the processors that still run on the legacy pipeline.
  Set<String> get legacyIds => Set.unmodifiable(_legacyIds);

  /// The id of every processor.
  Set<String> get ids => {..._engine.keys, ..._legacyIds};

  /// Whether the processor [id] runs on the engine.
  bool isEngine(String id) => _engine.containsKey(id);

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

  /// Hashes the part of a file that [artifact] owns: what the lock records and
  /// compares with the disk.
  ///
  /// The owned part of a patched file is told by the processor or the shared
  /// resource that owns it, anything else is hashed whole. A byte order mark never matters.
  String hash(Artifact artifact, List<int> bytes) {
    if (artifact.ownership != Ownership.patched) return digestOf(bytes);

    final read = [
      ..._engine.values.map((entry) => entry.ownedContent[artifact.path]),
      ..._resources.values.map((entry) => entry.ownedContent[artifact.path]),
    ].nonNulls.firstOrNull;

    if (read == null) return digestOf(bytes);

    final text = utf8.decode(bytes, allowMalformed: true);

    return digestOf(
      utf8.encode(read(text.startsWith('﻿') ? text.substring(1) : text)),
    );
  }
}
