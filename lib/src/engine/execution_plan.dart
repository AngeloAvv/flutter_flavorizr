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

import 'package:flutter_flavorizr/src/engine/flavorizr_processor.dart';

/// One processor of an [ExecutionPlan].
final class PlanStep {
  /// The processor to apply.
  final FlavorizrProcessor processor;

  /// Whether the processor was pulled in by a [FlavorizrProcessor.dependsOn]
  /// rather than requested, so that the plan can mark it `(auto)`.
  final bool auto;

  /// Creates a step.
  const PlanStep(this.processor, {required this.auto});
}

/// The processors of a run, in the order they must be applied.
final class ExecutionPlan {
  /// The steps, in execution order.
  final List<PlanStep> steps;

  /// Creates a plan applying [steps] in order.
  const ExecutionPlan(this.steps);
}

/// Resolves the plan that runs the [requested] processors out of [available].
///
/// [requested] holds processor ids. The plan is deterministic: it depends only
/// on the processors and their declared edges, never on the order of
/// [available] or [requested].
ExecutionPlan resolveExecutionPlan(
  Iterable<FlavorizrProcessor> available, {
  required Iterable<String> requested,
}) {
  final byId = {for (final processor in available) processor.id: processor};
  final requestedIds = requested.toSet();

  // Expand the request with every transitive dependency.
  final included = <String>{};
  final pending = [...requestedIds];
  while (pending.isNotEmpty) {
    final id = pending.removeLast();
    if (included.add(id)) {
      pending.addAll(byId[id]!.dependsOn);
    }
  }

  // What has to run before each processor: its dependencies, plus the
  // `after` ones that are in the plan anyway.
  final prerequisites = {
    for (final id in included)
      id: {
        ...byId[id]!.dependsOn,
        ...byId[id]!.after.where(included.contains),
      },
  };

  // Kahn's algorithm. Among the processors that are ready, the smallest id
  // always goes first, so the order depends on the ids alone.
  final remaining = {...included};
  final done = <String>{};
  final steps = <PlanStep>[];
  while (remaining.isNotEmpty) {
    final ready =
        remaining.where((id) => prerequisites[id]!.every(done.contains)).toList()
          ..sort();
    final id = ready.first;
    remaining.remove(id);
    done.add(id);
    steps.add(PlanStep(byId[id]!, auto: !requestedIds.contains(id)));
  }

  return ExecutionPlan(steps);
}
