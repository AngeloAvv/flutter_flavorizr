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

import 'dart:collection';

import 'package:flutter_flavorizr/src/engine/flavorizr_processor.dart';
import 'package:flutter_flavorizr/src/exception/dependency_cycle_exception.dart';
import 'package:flutter_flavorizr/src/exception/duplicate_processor_exception.dart';
import 'package:flutter_flavorizr/src/exception/unknown_processor_exception.dart';

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
/// [available] or [requested]: ties between processors that could run in any
/// order are broken by id.
///
/// The plan holds the requested processors plus, transitively, every processor
/// they [FlavorizrProcessor.dependsOn]; those are marked [PlanStep.auto].
/// [FlavorizrProcessor.after] never adds a processor, it only orders the ones
/// that are in the plan anyway. Apart from their ids, processors that are not
/// in the plan are not inspected, so a broken declaration of an unused
/// processor is harmless.
///
/// Throws a [DuplicateProcessorException] when two [available] processors
/// share an id, an [UnknownProcessorException] when a requested id or a
/// `dependsOn` matches no processor, and a [DependencyCycleException] when
/// the processors of the plan wait for each other.
ExecutionPlan resolveExecutionPlan(
  Iterable<FlavorizrProcessor> available, {
  required Iterable<String> requested,
}) {
  final byId = <String, FlavorizrProcessor>{};
  for (final processor in available) {
    if (byId.containsKey(processor.id)) {
      throw DuplicateProcessorException(processor.id);
    }
    byId[processor.id] = processor;
  }

  final requestedIds = requested.toSet();

  // Expand the request with every transitive dependency. Ids are visited in
  // sorted order so that, with several mistakes, the reported one is stable.
  final included = <String>{};
  final pending = Queue<(String, String?)>.of([
    for (final id in _sorted(requestedIds)) (id, null),
  ]);
  while (pending.isNotEmpty) {
    final (id, requiredBy) = pending.removeFirst();
    final processor = byId[id];
    if (processor == null) {
      throw UnknownProcessorException(id, requiredBy: requiredBy);
    }

    if (included.add(id)) {
      pending.addAll([
        for (final dependency in _sorted(processor.dependsOn)) (dependency, id),
      ]);
    }
  }

  // What has to run before each processor: its dependencies, plus the
  // `after` ones that are in the plan anyway.
  final prerequisites = {
    for (final id in included)
      id: {...byId[id]!.dependsOn, ...byId[id]!.after.where(included.contains)},
  };

  final cycle = _findCycle(prerequisites);
  if (cycle != null) {
    throw DependencyCycleException(cycle);
  }

  // Kahn's algorithm. Among the processors that are ready, the smallest id
  // always goes first, so the order depends on the ids alone.
  final remaining = {...included};
  final done = <String>{};
  final steps = <PlanStep>[];
  while (remaining.isNotEmpty) {
    final id = _sorted(
      remaining.where((id) => prerequisites[id]!.every(done.contains)),
    ).first;
    remaining.remove(id);
    done.add(id);
    steps.add(PlanStep(byId[id]!, auto: !requestedIds.contains(id)));
  }

  return ExecutionPlan(steps);
}

/// The ids of [ids] in ascending order: the stable key of the whole module.
List<String> _sorted(Iterable<String> ids) => ids.toList()..sort();

/// Finds a cycle in the graph that maps each id to the ids that must run
/// before it, or returns `null` when there is none.
///
/// The cycle lists the ids along the path, each one waiting for the next, and
/// repeats the first id at the end (`[a, b, a]`). The search follows ids in
/// sorted order, so the same graph always reports the same cycle.
List<String>? _findCycle(Map<String, Set<String>> prerequisites) {
  final visiting = <String>[];
  final finished = <String>{};

  List<String>? visit(String id) {
    visiting.add(id);
    for (final next in _sorted(prerequisites[id]!)) {
      final start = visiting.indexOf(next);
      if (start != -1) {
        return [...visiting.sublist(start), next];
      }

      if (!finished.contains(next)) {
        final cycle = visit(next);
        if (cycle != null) {
          return cycle;
        }
      }
    }
    visiting.removeLast();
    finished.add(id);

    return null;
  }

  for (final id in _sorted(prerequisites.keys)) {
    if (!finished.contains(id)) {
      final cycle = visit(id);
      if (cycle != null) {
        return cycle;
      }
    }
  }

  return null;
}
