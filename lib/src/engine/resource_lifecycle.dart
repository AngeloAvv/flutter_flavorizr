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
import 'package:flutter_flavorizr/src/engine/flavorizr_context.dart';
import 'package:flutter_flavorizr/src/engine/resource.dart';
import 'package:flutter_flavorizr/src/engine/resource_key.dart';
import 'package:flutter_flavorizr/src/exception/duplicate_resource_exception.dart';
import 'package:flutter_flavorizr/src/exception/unregistered_resource_exception.dart';

/// Applies one step of the plan, with a context that gives access to the
/// resources the step requires.
///
/// The context is created for the step alone. When the runner returns, the
/// artifacts the step tracked on it are tracked on the context of the run too.
typedef StepRunner =
    Future<void> Function(PlanStep step, FlavorizrContext stepContext);

/// Drives the [Resource]s of a run along an [ExecutionPlan].
///
/// Each resource that a step requires is set up once, right before the first
/// step that requires it, and torn down once, right after the last one, so it
/// lives only as long as it is needed. Resources that no step requires are
/// never set up.
///
/// [run] guarantees the teardown of every resource that was set up, whatever
/// happens: a failing step, a failing [Resource.setup] of another resource or
/// a failing [Resource.teardown]. The semantics are:
///
/// * The first failure aborts the run: no further step is applied and no
///   further resource is set up. It is the error [run] throws.
/// * Every resource that is still open is then torn down, in the reverse
///   order of their setup, with `success: false`.
/// * A failing teardown never masks an earlier failure and never prevents the
///   other teardowns. It is logged and dropped, unless nothing had failed yet:
///   then it is the failure of the run.
/// * A resource whose setup threw is not torn down, as it has no value.
class ResourceLifecycle {
  final ExecutionPlan _plan;
  final Map<ResourceKey<Object?>, Resource<Object?>> _resources;

  /// The keys to set up before the step at an index, in setup order.
  final List<List<ResourceKey<Object?>>> _setupBefore;

  /// The keys to tear down after the step at an index.
  final List<Set<ResourceKey<Object?>>> _teardownAfter;

  /// Prepares the lifecycle of [resources] along [plan].
  ///
  /// This is the plan time check: throws an [UnregisteredResourceException]
  /// when a step requires a resource that is not in [resources], and a
  /// [DuplicateResourceException] when two of them share a key.
  factory ResourceLifecycle(
    ExecutionPlan plan,
    Iterable<Resource<Object?>> resources,
  ) {
    final registered = <ResourceKey<Object?>, Resource<Object?>>{};
    for (final resource in resources) {
      if (registered.containsKey(resource.key)) {
        throw DuplicateResourceException(resource.key);
      }
      registered[resource.key] = resource;
    }

    final setupBefore = [for (final _ in plan.steps) <ResourceKey<Object?>>[]];
    final teardownAfter = [
      for (final _ in plan.steps) <ResourceKey<Object?>>{},
    ];
    final firstConsumer = <ResourceKey<Object?>, int>{};
    final lastConsumer = <ResourceKey<Object?>, int>{};
    for (final (index, step) in plan.steps.indexed) {
      for (final key in _byName(step.processor.requires)) {
        if (!registered.containsKey(key)) {
          throw UnregisteredResourceException(
            key,
            requiredBy: step.processor.id,
          );
        }
        firstConsumer.putIfAbsent(key, () => index);
        lastConsumer[key] = index;
      }
    }

    for (final MapEntry(:key, value: first) in firstConsumer.entries) {
      setupBefore[first].add(key);
      teardownAfter[lastConsumer[key]!].add(key);
    }

    // The declaration order of `requires` is not meaningful: the name is the
    // stable key that decides which resource of a step is set up first.
    for (final keys in setupBefore) {
      keys.sort(_compareByName);
    }

    return ResourceLifecycle._(plan, registered, setupBefore, teardownAfter);
  }

  ResourceLifecycle._(
    this._plan,
    this._resources,
    this._setupBefore,
    this._teardownAfter,
  );

  static int _compareByName(ResourceKey<Object?> a, ResourceKey<Object?> b) =>
      a.name.compareTo(b.name);

  static List<ResourceKey<Object?>> _byName(
    Iterable<ResourceKey<Object?>> keys,
  ) => keys.toList()..sort(_compareByName);

  /// Applies the plan through [runStep], handing each step a copy of [ctx]
  /// that holds the resources the step requires.
  ///
  /// Throws the first failure of the run, after every resource that was set
  /// up has been torn down.
  Future<void> run(FlavorizrContext ctx, StepRunner runStep) async {
    // The resources that are set up and not torn down yet, in setup order.
    final open = <ResourceKey<Object?>, Object?>{};
    (Object, StackTrace)? failure;

    Future<void> tearDownAll(List<ResourceKey<Object?>> keys) async {
      for (final key in keys.reversed) {
        final value = open.remove(key);
        try {
          await _resources[key]!.teardown(ctx, value, success: failure == null);
        } catch (error, stackTrace) {
          if (failure == null) {
            failure = (error, stackTrace);
            // The run is aborted from here: what is left open is closed all
            // together, newest first, rather than in the order it was due.
            break;
          } else {
            ctx.logger.warn(
              'Teardown of the resource "${key.name}" failed: $error',
            );
          }
        }
      }
    }

    try {
      for (final (index, step) in _plan.steps.indexed) {
        for (final key in _setupBefore[index]) {
          open[key] = await _resources[key]!.setup(ctx);
        }

        final stepContext = FlavorizrContext(
          config: ctx.config,
          root: ctx.root,
          projectRoot: ctx.projectRoot,
          logger: ctx.logger,
          previousFlavors: ctx.previousFlavors,
          resources: {
            for (final key in step.processor.requires) key: open[key],
          },
        );
        await runStep(step, stepContext);

        // What the step declared is handed back to the context of the run.
        stepContext.tracked.forEach(ctx.track);

        await tearDownAll([
          for (final key in open.keys)
            if (_teardownAfter[index].contains(key)) key,
        ]);
        if (failure != null) {
          break;
        }
      }
    } catch (error, stackTrace) {
      failure = (error, stackTrace);
    }

    // Whatever is still open is there because the run was aborted.
    await tearDownAll(open.keys.toList());

    final failed = failure;
    if (failed != null) {
      Error.throwWithStackTrace(failed.$1, failed.$2);
    }
  }
}
