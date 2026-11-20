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

import 'package:flutter_flavorizr/src/engine/execution_plan.dart';
import 'package:flutter_flavorizr/src/engine/recipe/recipe_catalog.dart';
import 'package:flutter_flavorizr/src/entrypoint/processor_registry.dart';
import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';

/// What a run does: the processors of the engine, in the order they are
/// applied.
final class RunPlan {
  /// What was left out and why, ready to be shown as info messages.
  final List<String> messages;

  /// The processors that run on the engine, in execution order, with the ones
  /// that were pulled in by a dependency marked as such.
  final ExecutionPlan engine;

  /// The paths of the project the processors of [engine] work on.
  final Set<String> paths;

  /// The ids of every processor the run was asked for: what a processor of the
  /// engine needs to know about the steps it works with, but does not run
  /// itself.
  final Set<String> selected;

  /// Creates a plan.
  RunPlan({
    required this.messages,
    required this.engine,
    required this.paths,
    this.selected = const {},
  });

  /// Whether nothing is left to run.
  bool get isEmpty => engine.steps.isEmpty;
}

/// The platforms [config] has no flavors for, which are left out of a run.
Set<String> platformsWithoutFlavors(FlavorizrConfig config) => {
  if (!config.androidFlavorsAvailable) 'android',
  if (!config.iosFlavorsAvailable) 'ios',
  if (!config.macosFlavorsAvailable) 'macos',
  if (!config.linuxFlavorsAvailable) 'linux',
  if (!config.windowsFlavorsAvailable) 'windows',
};

/// The ids of the processors that a full run of [config] covers: the ones of
/// `ProcessorRegistry.fullRunIds`, but the ones of a platform [config] has no
/// flavors for.
///
/// A run that covers all of them is a *full* run, the only one that records the
/// flavors in the lock (see `updateLock`). A project that has no Linux flavors
/// can never run the Linux processors, so they are not part of what a full run
/// has to cover. Neither are the ones that have nothing to make for the
/// configuration: `ide:config` with no `ide`, `ios:launchScreen` with no launch
/// screen, the Firebase ones with no Firebase configuration on their
/// platform, and `huawei:agconnect` with no AppGallery Connect configuration.
Set<String> engineIdsFor(ProcessorRegistry registry, FlavorizrConfig config) {
  final skipped = platformsWithoutFlavors(config);

  // These have nothing to write for a configuration that does not ask for
  // what they make: no IDE, no launch screen, no Firebase configuration on
  // their platform, no AppGallery Connect configuration.
  final idle = {
    if (config.ide?.isEmpty ?? true) 'ide:config',
    if (config.launchScreenFlavors.isEmpty) 'ios:launchScreen',
    if (!config.androidFirebaseFlavorsAvailable) 'android:firebase',
    if (!config.iosFirebaseFlavorsAvailable) 'ios:firebase',
    if (!config.macosFirebaseFlavorsAvailable) 'macos:firebase',
    if (!config.androidAGConnectFlavorsAvailable) 'huawei:agconnect',
  };

  return {
    for (final id in registry.fullRunIds)
      if (!skipped.contains(id.split(':').first) && !idle.contains(id)) id,
  };
}

/// Resolves what to run for [targets].
///
/// A target is the name of a recipe or the id of a processor. Without targets,
/// its default recipe: `default` when the configuration defines it, `all` if
/// not. The recipes of the platforms with no flavors are left out, with
/// a message.
///
/// The processors are ordered by their dependencies.
///
/// Throws what `RecipeCatalog` and `resolveExecutionPlan` throw for a target or
/// a recipe that is not valid.
RunPlan resolveRunPlan({
  required ProcessorRegistry registry,
  required FlavorizrConfig config,
  List<String> targets = const [],
}) {
  final catalog = RecipeCatalog(
    processorIds: registry.ids,
    recipes: config.recipes ?? const {},
    defaultRecipe: config.defaultRecipe,
  );
  final resolution = catalog.resolve(
    targets,
    platformsWithoutFlavors: platformsWithoutFlavors(config),
  );
  final engine = resolveExecutionPlan(
    registry.engineProcessors.values,
    requested: resolution.processorIds,
  );

  return RunPlan(
    messages: resolution.messages,
    engine: engine,
    paths: registry.pathsOf(engine.steps.map((step) => step.processor)),
    selected: Set.unmodifiable(resolution.processorIds),
  );
}
