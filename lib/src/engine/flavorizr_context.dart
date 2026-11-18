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

import 'dart:io';

import 'package:flutter_flavorizr/src/engine/artifact.dart';
import 'package:flutter_flavorizr/src/engine/resource_key.dart';
import 'package:flutter_flavorizr/src/engine/shadow/workspace_paths.dart';
import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:flutter_flavorizr/src/parser/models/flavors/flavor.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

/// Everything a `FlavorizrProcessor` may know about and do to the run.
///
/// The context separates two directory trees:
///
/// * [root] is the shadow workspace. Processors write there, and only there.
/// * [projectRoot] is the real project. It is used only to read inputs the
///   user provides, such as icon or Firebase source files.
///
/// Every path a processor uses must be resolved through [resolve] or
/// [resolveProject]. Neither the process working directory nor the relative
/// paths of `K` are ever valid on their own.
class FlavorizrContext {
  /// The resolved configuration of the run.
  final Flavorizr config;

  /// The shadow workspace, where processors write.
  final Directory root;

  /// The real project, used only to read user inputs.
  final Directory projectRoot;

  /// The logger of the run.
  final Logger logger;

  /// The names of the flavors recorded in the lock by the previous run.
  ///
  /// Comparing it with the keys of [desiredFlavors] tells which flavors were
  /// removed from the configuration. It is empty on the first run.
  final Set<String> previousFlavors;

  /// The id of the processor this context was created for, or `null` for the
  /// context of the whole run.
  ///
  /// It is what [previousObjectsOf] and [ownObjects] speak for.
  final String? processorId;

  /// The ids of every processor the run was asked for, the ones that run on
  /// the legacy pipeline too.
  ///
  /// A processor that depends on a step it does not run itself, such as the
  /// launch screen the plist points to, reads it here and not in the
  /// configuration: what a run does depends on the targets it is given.
  final Set<String> selected;

  final Map<ResourceKey<Object?>, Object?> _resources;
  final List<Artifact> _tracked = [];
  final Map<String, List<Artifact>> _trackedBy = {};
  final Map<String, Map<String, Set<String>>> _previousObjects;
  final Map<String, Map<String, Set<String>>> _ownedObjects = {};

  /// Creates a context.
  ///
  /// [resources] holds the values of the shared resources the engine already
  /// set up for the processor, by key. [previousObjects] holds the UUIDs of the
  /// pbxproj objects the lock recorded, by processor id and then by path of the
  /// project file, and [processorId] the processor the context is for.
  FlavorizrContext({
    required this.config,
    required Directory root,
    required Directory projectRoot,
    required this.logger,
    Set<String> previousFlavors = const {},
    Map<ResourceKey<Object?>, Object?> resources = const {},
    this.processorId,
    Map<String, Map<String, Set<String>>> previousObjects = const {},
    Set<String> selected = const {},
  }) : selected = Set.unmodifiable(selected),
       _resources = Map.of(resources),
       _previousObjects = _canonicalObjects(previousObjects),
       root = Directory(p.normalize(root.absolute.path)),
       projectRoot = Directory(p.normalize(projectRoot.absolute.path)),
       previousFlavors = Set.unmodifiable(previousFlavors);

  /// The flavors the configuration asks for, by name.
  Map<String, Flavor> get desiredFlavors => config.flavors;

  /// The artifacts declared so far through [track], in declaration order.
  List<Artifact> get tracked => List.unmodifiable(_tracked);

  /// The artifacts of [tracked] that were attributed to a processor through
  /// [trackFor], by processor id.
  ///
  /// The keys are the processors that ran: a processor that tracked nothing
  /// maps to an empty list. This is what tells which processor produced what,
  /// and which processors the run covers.
  Map<String, List<Artifact>> get trackedByProcessor => Map.unmodifiable({
    for (final entry in _trackedBy.entries)
      entry.key: List<Artifact>.unmodifiable(entry.value),
  });

  /// Declares that the processor owns [artifact].
  ///
  /// The path of [artifact] is relative to the project and must stay within
  /// [root], otherwise an [ArgumentError] is thrown. [artifact] is stored as
  /// it is, so that richer artifact types keep their information.
  void track(Artifact artifact) {
    resolve(artifact.path);

    _tracked.add(artifact);
  }

  /// Tracks [artifacts] and attributes them to the processor [processorId].
  ///
  /// It is how the engine hands the artifacts of a step back to the context of
  /// the run, keeping the processor they came from. Nothing is tracked when one
  /// of the paths leaves [root] (see [track]).
  void trackFor(String processorId, Iterable<Artifact> artifacts) {
    final list = artifacts.toList();

    for (final artifact in list) {
      resolve(artifact.path);
    }

    list.forEach(track);
    _trackedBy.putIfAbsent(processorId, () => []).addAll(list);
  }

  /// The UUIDs of the pbxproj objects the lock recorded for each processor, by
  /// processor id and then by canonical path of the project file.
  ///
  /// A path of the lock that is not a path of the project is ignored here, as
  /// the reconciliation reports it.
  Map<String, Map<String, Set<String>>> get previousObjects => _previousObjects;

  /// The UUIDs of the objects that the processor of this context owned the
  /// last time, in the project file at [path] (relative to the project).
  ///
  /// They are what the lock recorded, so the objects a processor created in an
  /// earlier run. A processor that no longer wants one removes it by UUID: see
  /// `OwnedObjects`. It is empty on the first run, and for a file the
  /// processor owned no object of.
  ///
  /// Throws a [StateError] on a context that is not for a processor.
  Set<String> previousObjectsOf(String path) {
    final id = _requireProcessor();
    final canonical = tryCanonicalPath(path);

    return Set.unmodifiable(
      canonical == null
          ? const <String>{}
          : _previousObjects[id]?[canonical] ?? const <String>{},
    );
  }

  /// The UUIDs of the objects the processors declared through [ownObjects] so
  /// far, by processor id and then by canonical path of the project file.
  ///
  /// A processor that never called [ownObjects] has no entry: the lock keeps
  /// what it recorded for it. One that called it with nothing has an empty set,
  /// which is how the lock learns it owns nothing anymore.
  Map<String, Map<String, Set<String>>> get ownedObjects =>
      _frozen(_ownedObjects);

  /// Declares that the processor owns the pbxproj objects with these [uuids] in
  /// the project file at [path], relative to the project: the lock records them,
  /// and the next run finds them through [previousObjectsOf].
  ///
  /// The UUIDs are added to the ones declared before for [path], and replace
  /// what the lock held for it: declare **every** object that is still owned,
  /// not only the new ones. A file the processor stops declaring keeps what the
  /// lock had.
  ///
  /// The path must stay within [root], otherwise an [ArgumentError] is thrown.
  /// Throws a [StateError] on a context that is not for a processor.
  void ownObjects(String path, Iterable<String> uuids) =>
      ownObjectsFor(_requireProcessor(), {path: Set.of(uuids)});

  /// Declares the objects [owned], by canonical path of the project file, as
  /// the ones the processor [processorId] owns.
  ///
  /// It is how the engine hands the objects of a step back to the context of
  /// the run, as [trackFor] does for artifacts.
  void ownObjectsFor(String processorId, Map<String, Set<String>> owned) {
    for (final MapEntry(key: path, value: uuids) in owned.entries) {
      resolve(path);

      _ownedObjects
          .putIfAbsent(processorId, () => {})
          .putIfAbsent(canonicalPath(path), () => {})
          .addAll(uuids);
    }
  }

  String _requireProcessor() =>
      processorId ??
      (throw StateError(
        'Objects are owned by a processor: use the context the engine '
        'created for it.',
      ));

  static Map<String, Map<String, Set<String>>> _canonicalObjects(
    Map<String, Map<String, Set<String>>> objects,
  ) {
    final result = <String, Map<String, Set<String>>>{};

    for (final MapEntry(key: id, value: byPath) in objects.entries) {
      for (final MapEntry(key: path, value: uuids) in byPath.entries) {
        final canonical = tryCanonicalPath(path);

        if (canonical == null) continue;

        result
            .putIfAbsent(id, () => {})
            .putIfAbsent(canonical, () => {})
            .addAll(uuids);
      }
    }

    return _frozen(result);
  }

  static Map<String, Map<String, Set<String>>> _frozen(
    Map<String, Map<String, Set<String>>> objects,
  ) => Map.unmodifiable({
    for (final MapEntry(key: id, value: byPath) in objects.entries)
      id: Map<String, Set<String>>.unmodifiable({
        for (final MapEntry(key: path, value: uuids) in byPath.entries)
          path: Set<String>.unmodifiable(uuids),
      }),
  });

  /// Returns the value of the shared resource identified by [key].
  ///
  /// The processor must list [key] in `FlavorizrProcessor.requires`. Throws a
  /// [StateError] when the resource is not available.
  T resource<T>(ResourceKey<T> key) {
    if (!_resources.containsKey(key)) {
      throw StateError(
        'The resource `${key.name}` is not available: '
        'the processor must declare it in `requires`',
      );
    }

    return _resources[key] as T;
  }

  /// Resolves [relativePath], a path relative to the project, below [root].
  ///
  /// The result is absolute and normalized. Throws an [ArgumentError] when
  /// [relativePath] leaves [root], e.g. through `..` or an absolute path.
  ///
  /// The check is lexical: symbolic links are not resolved, so the shadow
  /// workspace must not contain links pointing outside of it.
  String resolve(String relativePath) => _resolveIn(root, relativePath);

  /// Resolves [relativePath], a path relative to the project, below
  /// [projectRoot]. Use it only to read user inputs.
  ///
  /// The result is absolute and normalized. Throws an [ArgumentError] when
  /// [relativePath] leaves [projectRoot], e.g. through `..` or an absolute
  /// path.
  String resolveProject(String relativePath) =>
      _resolveIn(projectRoot, relativePath);

  static String _resolveIn(Directory base, String relativePath) {
    final resolved = p.normalize(p.join(base.path, relativePath));

    if (resolved != base.path && !p.isWithin(base.path, resolved)) {
      throw ArgumentError.value(
        relativePath,
        'relativePath',
        'must stay within `${base.path}`',
      );
    }

    return resolved;
  }
}
