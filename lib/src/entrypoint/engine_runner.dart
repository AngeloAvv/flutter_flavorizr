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

import 'package:flutter_flavorizr/src/engine/adopt/legacy_artifacts.dart';
import 'package:flutter_flavorizr/src/engine/conflict/conflict_content.dart';
import 'package:flutter_flavorizr/src/engine/conflict/conflict_policy.dart';
import 'package:flutter_flavorizr/src/engine/conflict/conflict_resolver.dart';
import 'package:flutter_flavorizr/src/engine/conflict/conflict_terminal.dart';
import 'package:flutter_flavorizr/src/engine/lock/flavorizr_lock.dart';
import 'package:flutter_flavorizr/src/engine/recipe/built_in_recipes.dart';
import 'package:flutter_flavorizr/src/engine/lock/lock_store.dart';
import 'package:flutter_flavorizr/src/engine/ownership.dart';
import 'package:flutter_flavorizr/src/engine/recorded_output.dart';
import 'package:flutter_flavorizr/src/engine/plan_executor.dart';
import 'package:flutter_flavorizr/src/engine/reconcile/reconciliation.dart';
import 'package:flutter_flavorizr/src/engine/shadow/workspace_diff.dart';
import 'package:flutter_flavorizr/src/engine/step_observer.dart';
import 'package:flutter_flavorizr/src/entrypoint/adopt_runner.dart';
import 'package:flutter_flavorizr/src/entrypoint/cli_context.dart';
import 'package:flutter_flavorizr/src/entrypoint/run_plan.dart';
import 'package:flutter_flavorizr/src/exception/lock_not_written_exception.dart';
import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:mason_logger/mason_logger.dart';

/// What a run of the engine would do to the project, found out in the shadow
/// workspace: nothing was written when it is built.
final class EnginePreview {
  /// The lock of the project, or `null` when it has none. For a project that
  /// had none and was flavorized before, it is the baseline [adopted] worked
  /// out, which is not in a file.
  final FlavorizrLock? previous;

  /// What was recorded as the baseline of a project that had no lock, and files
  /// flavorizr made before there was one, or `null`.
  final FirstRunAdoption? adopted;

  /// The flavors that changed and the files that are garbage collected.
  final Reconciliation reconciliation;

  /// Every change to the project, the deletions included.
  final WorkspaceDiff diff;

  /// Creates a preview.
  const EnginePreview({
    required this.previous,
    required this.reconciliation,
    required this.diff,
    this.adopted,
  });

  /// The changes a run would write, or ask about: everything but the files it
  /// leaves alone.
  List<FileChange> get changes => [
    for (final change in diff.changes)
      if (change.disposition == ChangeDisposition.apply ||
          change.disposition == ChangeDisposition.conflict ||
          change.disposition == ChangeDisposition.blocked)
        change,
  ];

  /// Whether files of the project would change, or be asked about.
  bool get hasChanges => changes.isNotEmpty;

  /// Whether a change would lose something edited by hand.
  bool get hasConflicts => diff.hasConflicts;
}

/// The outcome of [runEngine].
final class EngineRun {
  /// What happened to each processor. Its exit code is not `0` when one failed.
  final ExecutionReport report;

  /// What the run found, or `null` when a processor failed before it could be
  /// told.
  final EnginePreview? preview;

  /// Whether the changes were written to the project, and the lock with them.
  final bool applied;

  /// Whether the run was stopped because [approve] said no.
  final bool cancelled;

  /// What was decided about the conflicts, or `null` when the run did not get
  /// to decide: it was a dry run, it was cancelled, or it failed first.
  final ConflictResolution? resolution;

  /// Creates an outcome.
  const EngineRun({
    required this.report,
    this.preview,
    this.applied = false,
    this.cancelled = false,
    this.resolution,
  });
}

/// Runs the processors of [plan] on a shadow workspace of the project, and
/// returns what that would change.
///
/// With no [approve], that is all: it is a dry run, and nothing is written. With
/// [approve], it is asked once the changes are known, and if it says yes the
/// conflicts are resolved (see [ConflictResolver]: [policy] and [yes] are the
/// `--on-conflict` and `--yes` flags; [overwriteScaffold] is
/// `--overwrite-scaffold`: a scaffold file is the user's once it exists, and
/// only this replaces it), the changes are written back atomically
/// and the lock is written last.
///
/// An [observer] is told when each processor starts and ends, and takes over the
/// summary of a run that went well. Conflicts are asked about on [terminal],
/// which is the one of [context] by default.
///
/// A project with no `flavorizr.lock` that has files flavorizr made before there
/// was one (2.x, or a lost lock) is **adopted** first: what is on disk is the
/// baseline, as `flavorizr adopt` records it, so that the run shows what 3.x
/// changes in those files and not a conflict on each of them. The baseline is
/// not written on its own: the run that writes puts it in the lock together with
/// its changes, once they are approved, and a dry run writes nothing. A project
/// that has none of those files is not adopted.
///
/// A processor that fails ends the run with nothing written, and its error is in
/// the report. Everything else that goes wrong, such as a conflict nobody can
/// resolve or a lock that cannot be read, is thrown: see `ExitCodes.of`.
Future<EngineRun> runEngine(
  CliContext context, {
  required FlavorizrConfig config,
  required RunPlan plan,
  required Logger logger,
  StepObserver? observer,
  ConflictTerminal? terminal,
  Future<bool> Function(EnginePreview preview)? approve,
  ConflictPolicy? policy,
  bool yes = false,
  bool overwriteScaffold = false,
}) async {
  final registry = context.registry;
  final store = LockStore(context.projectRoot, runningVersion: context.version);
  var previous = await store.read();
  FirstRunAdoption? adopted;
  EnginePreview? preview;
  var applied = false;
  var cancelled = false;
  ConflictResolution? decided;

  if (previous == null) {
    final evidence = findLegacyArtifacts(
      context.projectRoot,
      flavors: config.flavors.keys,
    );

    if (evidence.isNotEmpty) {
      // The whole project, as `flavorizr adopt` does, so that the run of the
      // rest of it finds its baseline. A project that is not whole (a
      // processor of the default recipe cannot read what it is missing) is
      // adopted for the processors of this run.
      final candidates = [
        // Whatever the default recipe is: the baseline is the whole project.
        (
          resolveRunPlan(
            registry: registry,
            config: config,
            targets: const [allRecipeName],
          ),
          false,
        ),
        (plan, true),
      ];
      final tried = <String>{};
      AdoptRun? failed;

      for (final (candidate, partial) in candidates) {
        final key = [
          for (final step in candidate.engine.steps) step.processor.id,
        ].join(',');

        if (candidate.engine.steps.isEmpty || !tried.add(key)) continue;

        final run = await runAdoption(
          context,
          config: config,
          plan: candidate,
          named: const {},
          // What it says is said by the run, which is the one the user asked
          // for.
          logger: Logger(level: Level.quiet),
          write: false,
        );

        if (run.report.succeeded) {
          adopted = FirstRunAdoption(
            evidence: evidence,
            adoption: run.adoption!,
            partial: partial,
          );
          previous = adopted.adoption.lock;
          failed = null;
          break;
        }

        failed = run;
      }

      if (failed != null) {
        logger.err(
          'The project has files of flavorizr from before there was a '
          'flavorizr.lock, and could not be read as the baseline of the run:\n'
          '${failed.report.render()}',
        );

        return EngineRun(report: failed.report);
      }
    }
  }

  final report = await PlanExecutor(logger: logger, observer: observer).execute(
    plan.engine,
    config: config,
    projectRoot: context.projectRoot,
    paths: plan.paths,
    resources: registry.resources,
    selected: plan.selected,
    previousFlavors: previous?.flavorNames ?? const {},
    previousObjects: {
      for (final MapEntry(key: id, value: lock)
          in previous?.processors.entries ??
              const <MapEntry<String, ProcessorLock>>[])
        if (lock.objects.isNotEmpty) id: lock.objects,
    },
    previousKeys: {
      for (final MapEntry(key: id, value: lock)
          in previous?.processors.entries ??
              const <MapEntry<String, ProcessorLock>>[])
        if (lock.keys.isNotEmpty) id: lock.keys,
    },
    previousOutputs: {
      for (final MapEntry(key: id, value: lock)
          in previous?.processors.entries ??
              const <MapEntry<String, ProcessorLock>>[])
        if (lock.inputs.isNotEmpty)
          id: {
            for (final MapEntry(key: path, value: inputs)
                in lock.inputs.entries)
              if (lock.files[path]?.hash case final hash?)
                path: RecordedOutput(hash: hash, inputs: inputs),
          },
    },
    previousFiles: [
      for (final lock in previous?.processors.values ?? const <ProcessorLock>[])
        ...lock.files.keys,
    ],
    commit: (shadow, ctx) async {
      final reconciliation = await reconcile(
        projectRoot: shadow.projectRoot,
        paths: shadow.paths,
        previous: previous,
        produced: ctx.trackedByProcessor,
        tracked: ctx.tracked,
        ownedHashes: {
          for (final artifact in ctx.tracked)
            // A scaffold is hashed too, for the lock to say what was written.
            if ((artifact.ownership.isHashed ||
                    artifact.ownership == Ownership.scaffold) &&
                File(ctx.resolve(artifact.path)).existsSync())
              artifact.path: registry.hash(
                artifact,
                File(ctx.resolve(artifact.path)).readAsBytesSync(),
              ),
        },
        ownedObjects: ctx.ownedObjects,
        ownedKeys: ctx.ownedKeys,
        desiredFlavors: config.flavorFingerprints,
        availableProcessors: engineIdsFor(registry, config),
        flavorizrVersion: context.version,
        hasher: registry.hash,
        foreignReader: registry.foreignReader,
      );
      final diff = reconciliation.applyTo(
        await shadow.diff(
          tracked: ctx.tracked,
          overwriteScaffold: overwriteScaffold,
          edited: ctx.edited,
          recordedHashes: {
            for (final processor
                in previous?.processors.values ?? const <ProcessorLock>[])
              for (final entry in processor.files.entries)
                if (entry.value.hash != null) entry.key: entry.value.hash!,
          },
          hasher: registry.hash,
        ),
      );

      preview = EnginePreview(
        previous: previous,
        reconciliation: reconciliation,
        diff: diff,
        adopted: adopted,
      );

      if (approve == null) return;

      if (!await approve(preview!)) {
        cancelled = true;

        return;
      }

      final resolution = await ConflictResolver(
        terminal: terminal ?? context.terminal,
        content: reconciliation.conflictContent(ShadowConflictContent(shadow)),
        policy: policy,
        yes: yes,
      ).resolve(diff);
      decided = resolution;
      // Built and staged before anything is written, committed after
      // everything was: a lock that cannot be written is found out while the
      // project is still untouched.
      final lock = reconciliation.lockAfter(diff: diff, resolution: resolution);
      // The baseline of an adoption is in no file yet: the lock is written even
      // when the run changes nothing.
      final staged = lock == previous && adopted == null
          ? null
          : await store.stage(lock);

      try {
        await shadow.copyBack(
          resolution.applyTo(diff),
          approvedConflicts: resolution.approved,
        );
      } on Object {
        await staged?.discard();

        rethrow;
      }

      try {
        await staged?.commit();
      } on Object catch (error) {
        throw LockNotWrittenException(error);
      }

      applied = true;
    },
  );

  return EngineRun(
    report: report,
    preview: preview,
    applied: applied,
    cancelled: cancelled,
    resolution: decided,
  );
}
