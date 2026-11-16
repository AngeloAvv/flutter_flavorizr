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
import 'package:flutter_flavorizr/src/engine/flavorizr_context.dart';
import 'package:flutter_flavorizr/src/engine/flavorizr_processor.dart';
import 'package:flutter_flavorizr/src/engine/resource.dart';
import 'package:flutter_flavorizr/src/engine/resource_key.dart';
import 'package:flutter_flavorizr/src/engine/resource_lifecycle.dart';
import 'package:flutter_flavorizr/src/exception/duplicate_resource_exception.dart';
import 'package:flutter_flavorizr/src/exception/unregistered_resource_exception.dart';
import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_utils.dart';

/// A resource that records what happens to it in [events].
class _FakeResource extends Resource<String> {
  @override
  final ResourceKey<String> key;

  final List<String> events;
  final Object? setupError;
  final Object? teardownError;

  /// The `success` flag of each teardown call.
  final List<bool> teardownSuccess = [];

  _FakeResource(String name, this.events, {this.setupError, this.teardownError})
    : key = ResourceKey<String>(name);

  String get name => key.name;

  @override
  Future<String> setup(FlavorizrContext ctx) async {
    events.add('setup $name');
    if (setupError != null) {
      throw setupError!;
    }

    return 'value of $name';
  }

  @override
  Future<void> teardown(
    FlavorizrContext ctx,
    String value, {
    required bool success,
  }) async {
    events.add('teardown $name');
    teardownSuccess.add(success);
    if (teardownError != null) {
      throw teardownError!;
    }
  }
}

/// A processor that records its run in [events], with what it read from the
/// resources it requires.
class _FakeProcessor extends FlavorizrProcessor {
  @override
  final String id;

  final List<_FakeResource> needs;
  final List<String> events;
  final Object? error;

  _FakeProcessor(this.id, this.events, {this.needs = const [], this.error});

  @override
  Set<ResourceKey<Object?>> get requires => {
    for (final resource in needs) resource.key,
  };

  @override
  Future<void> apply(FlavorizrContext ctx) async {
    final values = [for (final resource in needs) ctx.resource(resource.key)];
    events.add('apply $id ${values.join(',')}'.trim());
    if (error != null) {
      throw error!;
    }
  }
}

void main() {
  late FlavorizrContext ctx;
  late List<String> events;

  setUp(() {
    events = [];
    ctx = FlavorizrContext(
      config: Flavorizr.parse('''
flavors:
  apple:
    app:
      name: Apple
    android:
      applicationId: com.example.apple
'''),
      root: Directory('shadow'),
      projectRoot: Directory('project'),
      logger: TestUtils.quietLogger(),
    );
  });

  /// Plans every processor of [processors], in id order.
  ExecutionPlan planOf(List<_FakeProcessor> processors) => resolveExecutionPlan(
    processors,
    requested: processors.map((processor) => processor.id),
  );

  /// Runs [plan] through a lifecycle of [resources], applying each processor.
  Future<void> run(ExecutionPlan plan, List<_FakeResource> resources) =>
      ResourceLifecycle(
        plan,
        resources,
      ).run(ctx, (step, stepCtx) => step.processor.apply(stepCtx));

  group('ResourceLifecycle', () {
    test(
      'sets a resource up before its consumer and tears it down after',
      () async {
        final xcode = _FakeResource('xcode', events);
        final plan = planOf([
          _FakeProcessor('a', events, needs: [xcode]),
        ]);

        await run(plan, [xcode]);

        expect(events, [
          'setup xcode',
          'apply a value of xcode',
          'teardown xcode',
        ]);
        expect(xcode.teardownSuccess, [true]);
      },
    );

    test('shares one setup between every consumer', () async {
      final xcode = _FakeResource('xcode', events);
      final plan = planOf([
        _FakeProcessor('a', events, needs: [xcode]),
        _FakeProcessor('b', events, needs: [xcode]),
        _FakeProcessor('c', events, needs: [xcode]),
      ]);

      await run(plan, [xcode]);

      expect(events, [
        'setup xcode',
        'apply a value of xcode',
        'apply b value of xcode',
        'apply c value of xcode',
        'teardown xcode',
      ]);
    });

    test('tears a resource down right after its last consumer', () async {
      final xcode = _FakeResource('xcode', events);
      final plan = planOf([
        _FakeProcessor('a', events),
        _FakeProcessor('b', events, needs: [xcode]),
        _FakeProcessor('c', events),
      ]);

      await run(plan, [xcode]);

      expect(events, [
        'apply a',
        'setup xcode',
        'apply b value of xcode',
        'teardown xcode',
        'apply c',
      ]);
    });

    test('keeps overlapping resources open only while consumed', () async {
      final assets = _FakeResource('assets', events);
      final xcode = _FakeResource('xcode', events);
      final plan = planOf([
        _FakeProcessor('a', events, needs: [assets]),
        _FakeProcessor('b', events, needs: [assets, xcode]),
        _FakeProcessor('c', events, needs: [xcode]),
      ]);

      await run(plan, [assets, xcode]);

      expect(events, [
        'setup assets',
        'apply a value of assets',
        'setup xcode',
        'apply b value of assets,value of xcode',
        'teardown assets',
        'apply c value of xcode',
        'teardown xcode',
      ]);
    });

    test('sets resources up by name and tears them down in reverse', () async {
      final assets = _FakeResource('assets', events);
      final xcode = _FakeResource('xcode', events);
      final plan = planOf([
        _FakeProcessor('a', events, needs: [xcode, assets]),
      ]);

      await run(plan, [xcode, assets]);

      expect(events, [
        'setup assets',
        'setup xcode',
        'apply a value of xcode,value of assets',
        'teardown xcode',
        'teardown assets',
      ]);
    });

    test('never sets up a resource nobody requires', () async {
      final xcode = _FakeResource('xcode', events);
      final plan = planOf([_FakeProcessor('a', events)]);

      await run(plan, [xcode]);

      expect(events, ['apply a']);
    });

    test('runs the steps when no resource is involved', () async {
      final plan = planOf([
        _FakeProcessor('a', events),
        _FakeProcessor('b', events),
      ]);

      await run(plan, []);

      expect(events, ['apply a', 'apply b']);
    });

    test('hands a step only the resources it requires', () async {
      final assets = _FakeResource('assets', events);
      final xcode = _FakeResource('xcode', events);
      final plan = planOf([
        _FakeProcessor('a', events, needs: [assets]),
        _FakeProcessor('b', events, needs: [xcode]),
      ]);
      final seen = <String, Object?>{};

      await ResourceLifecycle(plan, [assets, xcode]).run(ctx, (step, stepCtx) {
        try {
          stepCtx.resource(assets.key);
          seen[step.processor.id] = 'assets';
        } on StateError {
          seen[step.processor.id] = 'none';
        }

        return Future.value();
      });

      expect(seen, {'a': 'assets', 'b': 'none'});
    });

    test('fails at plan time when a required resource is not registered', () {
      final xcode = _FakeResource('xcode', events);
      final plan = planOf([
        _FakeProcessor('a', events, needs: [xcode]),
      ]);

      expect(
        () => ResourceLifecycle(plan, []),
        throwsA(
          isA<UnregisteredResourceException>()
              .having((e) => e.key, 'key', xcode.key)
              .having((e) => e.requiredBy, 'requiredBy', 'a'),
        ),
      );
      expect(events, isEmpty);
    });

    group('when a processor fails', () {
      test(
        'tears its resource down as failed and rethrows the error',
        () async {
          final error = StateError('boom');
          final xcode = _FakeResource('xcode', events);
          final plan = planOf([
            _FakeProcessor('a', events, needs: [xcode], error: error),
          ]);

          await expectLater(run(plan, [xcode]), throwsA(same(error)));

          expect(events, [
            'setup xcode',
            'apply a value of xcode',
            'teardown xcode',
          ]);
          expect(xcode.teardownSuccess, [false]);
        },
      );

      test(
        'stops the run and tears every open resource down in reverse',
        () async {
          final assets = _FakeResource('assets', events);
          final xcode = _FakeResource('xcode', events);
          final later = _FakeResource('later', events);
          final plan = planOf([
            _FakeProcessor('a', events, needs: [assets]),
            _FakeProcessor('b', events, needs: [xcode], error: StateError('x')),
            _FakeProcessor('c', events, needs: [assets, later]),
          ]);

          await expectLater(
            run(plan, [assets, xcode, later]),
            throwsStateError,
          );

          expect(events, [
            'setup assets',
            'apply a value of assets',
            'setup xcode',
            'apply b value of xcode',
            'teardown xcode',
            'teardown assets',
          ]);
          expect(assets.teardownSuccess, [false]);
          expect(xcode.teardownSuccess, [false]);
        },
      );

      test(
        'still tears down a resource that was already finished as successful',
        () async {
          final assets = _FakeResource('assets', events);
          final plan = planOf([
            _FakeProcessor('a', events, needs: [assets]),
            _FakeProcessor('b', events, error: StateError('x')),
          ]);

          await expectLater(run(plan, [assets]), throwsStateError);

          expect(events, [
            'setup assets',
            'apply a value of assets',
            'teardown assets',
            'apply b',
          ]);
          expect(assets.teardownSuccess, [true]);
        },
      );
    });

    group('when a resource setup fails', () {
      test(
        'does not run the consumer and does not tear the resource down',
        () async {
          final error = StateError('no setup');
          final xcode = _FakeResource('xcode', events, setupError: error);
          final plan = planOf([
            _FakeProcessor('a', events, needs: [xcode]),
          ]);

          await expectLater(run(plan, [xcode]), throwsA(same(error)));

          expect(events, ['setup xcode']);
          expect(xcode.teardownSuccess, isEmpty);
        },
      );

      test(
        'tears down the resources already open and sets up no other',
        () async {
          final assets = _FakeResource('assets', events);
          final broken = _FakeResource(
            'broken',
            events,
            setupError: StateError('x'),
          );
          final zeta = _FakeResource('zeta', events);
          final plan = planOf([
            _FakeProcessor('a', events, needs: [assets]),
            _FakeProcessor('b', events, needs: [assets, broken, zeta]),
          ]);

          await expectLater(
            run(plan, [assets, broken, zeta]),
            throwsStateError,
          );

          expect(events, [
            'setup assets',
            'apply a value of assets',
            'setup broken',
            'teardown assets',
          ]);
          expect(assets.teardownSuccess, [false]);
        },
      );
    });

    group('when a teardown fails', () {
      test(
        'does not mask the failure of the run and tears the others down',
        () async {
          final original = StateError('original');
          final assets = _FakeResource('assets', events);
          final xcode = _FakeResource(
            'xcode',
            events,
            teardownError: StateError('teardown'),
          );
          final plan = planOf([
            _FakeProcessor(
              'a',
              events,
              needs: [assets, xcode],
              error: original,
            ),
          ]);

          await expectLater(
            run(plan, [assets, xcode]),
            throwsA(same(original)),
          );

          expect(events, [
            'setup assets',
            'setup xcode',
            'apply a value of assets,value of xcode',
            'teardown xcode',
            'teardown assets',
          ]);
          expect(assets.teardownSuccess, [false]);
        },
      );

      test(
        'fails a run that was successful and tears the others down as failed',
        () async {
          final error = StateError('teardown');
          final assets = _FakeResource('assets', events);
          final xcode = _FakeResource('xcode', events, teardownError: error);
          final plan = planOf([
            _FakeProcessor('a', events, needs: [assets, xcode]),
            _FakeProcessor('b', events, needs: [assets]),
            _FakeProcessor('c', events),
          ]);

          await expectLater(run(plan, [assets, xcode]), throwsA(same(error)));

          expect(events, [
            'setup assets',
            'setup xcode',
            'apply a value of assets,value of xcode',
            'teardown xcode',
            'teardown assets',
          ]);
          expect(xcode.teardownSuccess, [true]);
          expect(assets.teardownSuccess, [false]);
        },
      );

      test('reports the first teardown error when several fail', () async {
        final first = StateError('first');
        final assets = _FakeResource(
          'assets',
          events,
          teardownError: StateError('second'),
        );
        final xcode = _FakeResource('xcode', events, teardownError: first);
        final plan = planOf([
          _FakeProcessor('a', events, needs: [assets, xcode]),
        ]);

        await expectLater(run(plan, [assets, xcode]), throwsA(same(first)));

        expect(events, contains('teardown assets'));
      });
    });

    test('fails at plan time when a resource is registered twice', () {
      final plan = planOf([_FakeProcessor('a', events)]);

      expect(
        () => ResourceLifecycle(plan, [
          _FakeResource('xcode', events),
          _FakeResource('xcode', events),
        ]),
        throwsA(isA<DuplicateResourceException>()),
      );
    });
  });
}
