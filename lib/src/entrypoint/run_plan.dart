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
import 'package:flutter_flavorizr/src/entrypoint/legacy_pipeline.dart';
import 'package:flutter_flavorizr/src/entrypoint/processor_registry.dart';
import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';

/// What a run does: the processors of the engine, in the order they are
/// applied, and the ones the legacy pipeline applies afterwards.
final class RunPlan {
  /// What was left out and why, ready to be shown as info messages.
  final List<String> messages;

  /// The processors that run on the engine, in execution order, with the ones
  /// that were pulled in by a dependency marked as such.
  final ExecutionPlan engine;

  /// The instructions the legacy pipeline applies after the engine, in the
  /// order they were asked for.
  final List<LegacyStep> legacy;

  /// The paths of the project the processors of [engine] work on.
  final Set<String> paths;

  /// Creates a plan.
  RunPlan({
    required this.messages,
    required this.engine,
    required this.legacy,
    required this.paths,
  });

  /// Whether nothing is left to run.
  bool get isEmpty => engine.steps.isEmpty && legacy.isEmpty;
}

/// Resolves what to run for [targets].
///
/// A target is the name of a recipe or the id of a processor. Without targets,
/// the `instructions` of the configuration are run when it has any, as in 2.x,
/// otherwise its default recipe: `default` when the configuration defines it,
/// `all` if not. The recipes of the platforms with no flavors are left out, with
/// a message.
///
/// The processors that run on the engine are ordered by their dependencies,
/// and the others keep the order they were asked for. The engine goes first,
/// since it is the one that can be previewed and that refuses to run over
/// edits made by hand: nothing else is run when it fails.
///
/// Throws what `RecipeCatalog` and `resolveExecutionPlan` throw for a target or
/// a recipe that is not valid.
RunPlan resolveRunPlan({
  required ProcessorRegistry registry,
  required Flavorizr config,
  List<String> targets = const [],
}) {
  final catalog = RecipeCatalog(
    processorIds: registry.ids,
    recipes: config.recipes ?? const {},
    defaultRecipe: config.defaultRecipe,
  );
  final resolution = catalog.resolve(
    targets.isNotEmpty ? targets : config.instructions ?? const [],
    platformsWithoutFlavors: {
      if (!config.androidFlavorsAvailable) 'android',
      if (!config.iosFlavorsAvailable) 'ios',
      if (!config.macosFlavorsAvailable) 'macos',
      if (!config.linuxFlavorsAvailable) 'linux',
      if (!config.windowsFlavorsAvailable) 'windows',
    },
  );
  final engine = resolveExecutionPlan(
    registry.engineProcessors.values,
    requested: resolution.processorIds.where(registry.isEngine),
  );
  final dummyAssetsConfig =
      engine.steps.any((step) => step.processor.id == _androidIcons)
      ? _withoutIconFlavors(config)
      : config;

  return RunPlan(
    messages: resolution.messages,
    engine: engine,
    legacy: [
      for (final id in resolution.processorIds)
        if (!registry.isEngine(id))
          LegacyStep(
            id,
            id == _androidDummyAssets ? dummyAssetsConfig : config,
          ),
    ],
    paths: registry.pathsOf(engine.steps.map((step) => step.processor)),
  );
}

const _androidIcons = 'android:icons';
const _androidDummyAssets = 'android:dummyAssets';

/// [config] without the flavors that have a PNG icon.
///
/// In 2.x the icons of `android:icons` were copied over the placeholders of
/// `android:dummyAssets`, so a flavor with an icon ended up with its icon. The
/// engine runs first and a file it wrote cannot be overwritten by a processor
/// that runs later, so the placeholders are simply not made for those flavors:
/// the result is the same, and a placeholder never has to be told from a file
/// of the user.
Flavorizr _withoutIconFlavors(Flavorizr config) => Flavorizr(
  app: config.app,
  flavors: {
    for (final entry in config.flavors.entries)
      if ((entry.value.android?.icon ?? entry.value.app.icon) == null)
        entry.key: entry.value,
  },
  instructions: config.instructions,
  assetsUrl: config.assetsUrl,
  ide: config.ide,
);
