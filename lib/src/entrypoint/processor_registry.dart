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
import 'package:flutter_flavorizr/src/engine/processors/flutter/flutter_processors.dart';
import 'package:flutter_flavorizr/src/engine/recipe/built_in_recipes.dart';
import 'package:flutter_flavorizr/src/engine/recipe/recipe_catalog.dart';
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

  /// Creates a registry of [engine] processors and the legacy processors named
  /// by [legacyIds].
  ProcessorRegistry({
    Iterable<EngineProcessor> engine = const [],
    Iterable<String> legacyIds = const [],
  }) : _engine = {for (final entry in engine) entry.processor.id: entry},
       _legacyIds = {
         for (final id in legacyIds)
           if (!engine.any((entry) => entry.processor.id == id)) id,
       };

  /// The registry of this version: the Android and Flutter processors that
  /// were ported run on the engine, every other 2.x instruction on the legacy
  /// pipeline.
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
    legacyIds: Processor.defaultInstructionSet,
  );

  /// The processors that run on the engine, by id.
  Map<String, FlavorizrProcessor> get engineProcessors => {
    for (final entry in _engine.entries) entry.key: entry.value.processor,
  };

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
  Set<String> pathsOf(Iterable<FlavorizrProcessor> processors) => {
    for (final processor in processors) ..._engine[processor.id]!.paths,
  };

  /// Hashes the part of a file that [artifact] owns: what the lock records and
  /// compares with the disk.
  ///
  /// The owned part of a patched file is told by the processor that owns it,
  /// anything else is hashed whole. A byte order mark never matters.
  String hash(Artifact artifact, List<int> bytes) {
    if (artifact.ownership != Ownership.patched) return digestOf(bytes);

    final read = _engine.values
        .map((entry) => entry.ownedContent[artifact.path])
        .nonNulls
        .firstOrNull;

    if (read == null) return digestOf(bytes);

    final text = utf8.decode(bytes, allowMalformed: true);

    return digestOf(
      utf8.encode(read(text.startsWith('﻿') ? text.substring(1) : text)),
    );
  }
}
