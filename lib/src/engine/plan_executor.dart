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

import 'package:flutter_flavorizr/src/engine/execution_plan.dart';
import 'package:flutter_flavorizr/src/engine/execution_report.dart';
import 'package:flutter_flavorizr/src/engine/flavorizr_context.dart';
import 'package:flutter_flavorizr/src/engine/resource.dart';
import 'package:flutter_flavorizr/src/engine/resource_lifecycle.dart';
import 'package:flutter_flavorizr/src/engine/shadow/shadow_workspace.dart';
import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:mason_logger/mason_logger.dart';

export 'package:flutter_flavorizr/src/engine/execution_report.dart';

/// What to do with the result of a run that went well, while its shadow
/// workspace still exists.
///
/// [ctx] holds the artifacts the processors tracked. This is where the caller
/// diffs the workspace, resolves conflicts, copies the changes back and writes
/// the lock, in this order: the executor never does any of it itself.
typedef CommitRun =
    Future<void> Function(ShadowWorkspace shadow, FlavorizrContext ctx);

/// Applies an [ExecutionPlan] inside a [ShadowWorkspace], fail-fast.
///
/// The first processor that throws aborts the run: no further processor is
/// applied, every resource that was set up is torn down (see
/// [ResourceLifecycle.run]) and the shadow workspace is deleted. Nothing is
/// ever written to the real project on the way: that is the job of the commit
/// callback, which is not called when anything failed. So a failing run leaves
/// the project, and its lock file, untouched.
///
/// A failure of the run is reported, not thrown: see [ExecutionReport.exitCode]
/// for the exit code of the process.
class PlanExecutor {
  /// The logger of the run, which the report is printed through.
  final Logger logger;

  /// Creates an executor.
  const PlanExecutor({required this.logger});

  /// Applies [plan] to the project in [projectRoot], whose [paths] are copied
  /// to the shadow workspace the processors write to.
  ///
  /// [previousObjects] are the UUIDs of the pbxproj objects the lock recorded,
  /// by processor id and then by path of the project file: each processor reads
  /// its own through `FlavorizrContext.previousObjectsOf`.
  ///
  /// [resources] must hold every resource the plan requires. A resource a step
  /// requires and is missing, and an invalid [paths], throw before anything is
  /// applied.
  ///
  /// [commit] runs only when every processor completed, and the errors it
  /// throws are not caught, since the report would no longer tell what
  /// happened: the shadow workspace is deleted all the same. The summary of a
  /// run that went well is printed once [commit] returned.
  Future<ExecutionReport> execute(
    ExecutionPlan plan, {
    required Flavorizr config,
    required Directory projectRoot,
    required Iterable<String> paths,
    required CommitRun commit,
    Iterable<Resource<Object?>> resources = const [],
    Set<String> previousFlavors = const {},
    Map<String, Map<String, Set<String>>> previousObjects = const {},
    Directory? tempParent,
  }) {
    final lifecycle = ResourceLifecycle(plan, resources);

    return ShadowWorkspace.run(
      projectRoot: projectRoot,
      paths: paths,
      tempParent: tempParent,
      body: (shadow) async {
        final ctx = FlavorizrContext(
          config: config,
          root: shadow.root,
          projectRoot: shadow.projectRoot,
          logger: logger,
          previousFlavors: previousFlavors,
          previousObjects: previousObjects,
        );
        final completed = <String>[];
        String? currentId;
        Object? error;
        StackTrace? stackTrace;

        try {
          await lifecycle.run(ctx, (step, stepCtx) async {
            currentId = step.processor.id;
            await step.processor.apply(stepCtx);
            completed.add(step.processor.id);
            currentId = null;
          });
        } on Object catch (caught, trace) {
          error = caught;
          stackTrace = trace;
        }

        // A processor that threw is still the current one. When none is, the
        // failure is not a processor's: a resource failed to set up or down.
        final started = {...completed, ?currentId};
        final report = ExecutionReport(
          completed: completed,
          failed: currentId,
          skipped: [
            for (final step in plan.steps)
              if (!started.contains(step.processor.id)) step.processor.id,
          ],
          error: error,
          stackTrace: stackTrace,
        );

        if (!report.succeeded) {
          logger.err(report.render());
          logger.detail('${report.stackTrace}');

          return report;
        }

        // The summary comes after the commit: a run whose changes could not be
        // written must not be announced as a success.
        await commit(shadow, ctx);
        logger.info(report.render());

        return report;
      },
    );
  }
}
