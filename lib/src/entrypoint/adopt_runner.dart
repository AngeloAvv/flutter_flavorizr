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

import 'package:flutter_flavorizr/src/engine/adopt/adoption.dart';
import 'package:flutter_flavorizr/src/engine/adopt/legacy_artifacts.dart';
import 'package:flutter_flavorizr/src/engine/lock/lock_store.dart';
import 'package:flutter_flavorizr/src/engine/plan_executor.dart';
import 'package:flutter_flavorizr/src/engine/step_observer.dart';
import 'package:flutter_flavorizr/src/entrypoint/cli_context.dart';
import 'package:flutter_flavorizr/src/entrypoint/run_plan.dart';
import 'package:flutter_flavorizr/src/exception/lock_not_written_exception.dart';
import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:flutter_flavorizr/src/parser/models/flavors/flavor.dart';
import 'package:mason_logger/mason_logger.dart';

/// What the lock records for a flavor that was declared with `--flavors`: the
/// configuration of such a flavor is not known.
const adoptedFlavorFingerprint = 'adopted';

/// What a run recorded as its baseline when the project had no lock and had
/// files flavorizr made before there was one (see [findLegacyArtifacts]).
///
/// It lives in memory: only a run that writes (`apply`) puts it in
/// `flavorizr.lock`, together with its changes, and a `plan` or a `status` never
/// does.
final class FirstRunAdoption {
  /// The files that told the project was flavorized before: the first ones are
  /// enough to say so.
  final List<String> evidence;

  /// What was recorded.
  final Adoption adoption;

  /// Whether only the processors of the run were adopted, since another one of
  /// the default recipe could not read the project: the rest of it has no
  /// baseline.
  final bool partial;

  /// Creates the record of an adoption.
  const FirstRunAdoption({
    required this.evidence,
    required this.adoption,
    this.partial = false,
  });
}

/// The outcome of [runAdoption].
final class AdoptRun {
  /// What happened to each processor. Its exit code is not `0` when one failed.
  final ExecutionReport report;

  /// What was recorded, or `null` when a processor failed first.
  final Adoption? adoption;

  /// Creates an outcome.
  const AdoptRun({required this.report, this.adoption});
}

/// [config] with the flavors [historical], which it does not have: each one has
/// the settings, for each platform, of the first flavor of [config] that is built
/// for it.
///
/// They are flavors the project had and the configuration dropped before the
/// first run of 3.0. The processors make what they would make for them, which
/// tells the files to look for, and nothing is written.
FlavorizrConfig withHistoricalFlavors(
  FlavorizrConfig config,
  Iterable<String> historical,
) {
  final missing = historical
      .where((name) => !config.flavors.containsKey(name))
      .toSet();

  if (missing.isEmpty || config.flavors.isEmpty) return config;

  final template = Flavor(
    app: config.flavors.values.first.app,
    android: config.androidFlavors.values.firstOrNull?.android,
    ios: config.iosFlavors.values.firstOrNull?.ios,
    macos: config.macosFlavors.values.firstOrNull?.macos,
    linux: config.linuxFlavors.values.firstOrNull?.linux,
    windows: config.windowsFlavors.values.firstOrNull?.windows,
  );

  return config.withFlavors({
    ...config.flavors,
    for (final name in missing) name: template,
  });
}

/// Runs the processors of [plan] on a shadow workspace to learn the files they
/// make, and records the ones the project already has as its baseline in
/// `flavorizr.lock`, which is the only thing written: see [adoptProject].
///
/// The flavors [named] that [config] does not have are the ones the project had:
/// their files are recorded too, so that the next run removes them, as it does
/// for a flavor that was dropped.
///
/// A processor that fails ends the run with nothing written. With [write] unset
/// not even the lock is written: the baseline is only worked out and returned.
Future<AdoptRun> runAdoption(
  CliContext context, {
  required FlavorizrConfig config,
  required RunPlan plan,
  required Set<String> named,
  required Logger logger,
  StepObserver? observer,
  bool write = true,
}) async {
  // A flavor of the configuration is never historical, whatever it is named.
  final historical = {
    for (final name in named)
      if (!config.flavors.containsKey(name)) name,
  };
  final registry = context.registry;
  final all = withHistoricalFlavors(config, historical);
  final recordedFlavors = {
    ...config.flavorFingerprints,
    for (final name in historical)
      if (!config.flavors.containsKey(name)) name: adoptedFlavorFingerprint,
  };
  Adoption? adoption;

  final report = await PlanExecutor(logger: logger, observer: observer).execute(
    plan.engine,
    config: all,
    projectRoot: context.projectRoot,
    paths: plan.paths,
    resources: registry.resources,
    selected: plan.selected,
    adopting: true,
    commit: (shadow, ctx) async {
      adoption = await adoptProject(
        projectRoot: context.projectRoot,
        produced: ctx.trackedByProcessor,
        androidFlavors: all.androidFlavors.keys,
        iosFlavors: all.iosFlavors.keys,
        macosFlavors: all.macosFlavors.keys,
        windowsFlavors: all.windowsFlavors.keys,
        historicalFlavors: historical,
        flavors: recordedFlavors,
        availableProcessors: engineIdsFor(registry, config),
        flavorizrVersion: context.version,
        hasher: registry.hash,
        dummyAssets: context.dummyAssets,
        ownedObjects: ctx.ownedObjects,
        ownedKeys: ctx.ownedKeys,
      );

      if (!write) return;

      try {
        await LockStore(
          context.projectRoot,
          runningVersion: context.version,
        ).write(adoption!.lock);
      } on Object catch (error) {
        throw LockNotWrittenException(error);
      }
    },
  );

  return AdoptRun(report: report, adoption: adoption);
}
