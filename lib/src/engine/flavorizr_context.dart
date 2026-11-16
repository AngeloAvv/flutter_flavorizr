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

  final Map<ResourceKey<Object?>, Object?> _resources;
  final List<Artifact> _tracked = [];

  /// Creates a context.
  ///
  /// [resources] holds the values of the shared resources the engine already
  /// set up for the processor, by key.
  FlavorizrContext({
    required this.config,
    required Directory root,
    required Directory projectRoot,
    required this.logger,
    Set<String> previousFlavors = const {},
    Map<ResourceKey<Object?>, Object?> resources = const {},
  }) : _resources = Map.of(resources),
       root = Directory(p.normalize(root.absolute.path)),
       projectRoot = Directory(p.normalize(projectRoot.absolute.path)),
       previousFlavors = Set.unmodifiable(previousFlavors);

  /// The flavors the configuration asks for, by name.
  Map<String, Flavor> get desiredFlavors => config.flavors;

  /// The artifacts declared so far through [track], in declaration order.
  List<Artifact> get tracked => List.unmodifiable(_tracked);

  /// Declares that the processor owns [artifact].
  ///
  /// The path of [artifact] is relative to the project and must stay within
  /// [root]: it is stored normalized. Throws an [ArgumentError] otherwise.
  void track(Artifact artifact) {
    final path = p.relative(resolve(artifact.path), from: root.path);

    _tracked.add(Artifact(path));
  }

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
