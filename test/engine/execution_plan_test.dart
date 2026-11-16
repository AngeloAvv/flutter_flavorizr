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
import 'package:flutter_flavorizr/src/engine/flavorizr_processor.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeProcessor extends FlavorizrProcessor {
  @override
  final String id;

  @override
  final Set<String> dependsOn;

  @override
  final Set<String> after;

  const _FakeProcessor(
    this.id, {
    this.dependsOn = const {},
    this.after = const {},
  });

  @override
  Future<void> apply(FlavorizrContext ctx) async {}
}

/// The ids of [plan], in execution order.
List<String> _ids(ExecutionPlan plan) =>
    plan.steps.map((step) => step.processor.id).toList();

void main() {
  group('resolveExecutionPlan', () {
    test('plans a requested processor that has no dependencies', () {
      final plan = resolveExecutionPlan(
        [const _FakeProcessor('a'), const _FakeProcessor('b')],
        requested: ['a'],
      );

      expect(_ids(plan), ['a']);
      expect(plan.steps.single.auto, isFalse);
    });

    test('pulls in a dependency and runs it first, marked auto', () {
      final plan = resolveExecutionPlan(
        [
          const _FakeProcessor('android:buildGradle',
              dependsOn: {'android:flavorizrGradle'}),
          const _FakeProcessor('android:flavorizrGradle'),
        ],
        requested: ['android:buildGradle'],
      );

      expect(_ids(plan), ['android:flavorizrGradle', 'android:buildGradle']);
      expect(plan.steps.map((step) => step.auto), [true, false]);
    });

    test('pulls in dependencies transitively', () {
      final plan = resolveExecutionPlan(
        [
          const _FakeProcessor('c', dependsOn: {'b'}),
          const _FakeProcessor('b', dependsOn: {'a'}),
          const _FakeProcessor('a'),
          const _FakeProcessor('unrelated'),
        ],
        requested: ['c'],
      );

      expect(_ids(plan), ['a', 'b', 'c']);
      expect(plan.steps.map((step) => step.auto), [true, true, false]);
    });

    test('does not mark a dependency that was requested as auto', () {
      final plan = resolveExecutionPlan(
        [
          const _FakeProcessor('b', dependsOn: {'a'}),
          const _FakeProcessor('a'),
        ],
        requested: ['b', 'a'],
      );

      expect(_ids(plan), ['a', 'b']);
      expect(plan.steps.map((step) => step.auto), [false, false]);
    });

    test('pulls a shared dependency in once', () {
      final plan = resolveExecutionPlan(
        [
          const _FakeProcessor('b', dependsOn: {'a'}),
          const _FakeProcessor('c', dependsOn: {'a'}),
          const _FakeProcessor('a'),
        ],
        requested: ['b', 'c'],
      );

      expect(_ids(plan), ['a', 'b', 'c']);
    });

    test('orders after only when both processors are in the plan', () {
      final processors = [
        const _FakeProcessor('a', after: {'b'}),
        const _FakeProcessor('b'),
      ];

      expect(
        _ids(resolveExecutionPlan(processors, requested: ['a', 'b'])),
        ['b', 'a'],
      );
    });

    test('never pulls in a processor through after', () {
      final plan = resolveExecutionPlan(
        [const _FakeProcessor('a', after: {'b'}), const _FakeProcessor('b')],
        requested: ['a'],
      );

      expect(_ids(plan), ['a']);
    });

    test('ignores an after that points at an unknown id', () {
      final plan = resolveExecutionPlan(
        [const _FakeProcessor('a', after: {'ghost'})],
        requested: ['a'],
      );

      expect(_ids(plan), ['a']);
    });

    test('orders after across a pulled in dependency', () {
      final plan = resolveExecutionPlan(
        [
          const _FakeProcessor('a', dependsOn: {'z'}),
          const _FakeProcessor('b', after: {'z'}),
          const _FakeProcessor('z'),
        ],
        requested: ['b', 'a'],
      );

      expect(_ids(plan), ['z', 'a', 'b']);
    });

    test('ignores the order the processors were requested in', () {
      final processors = [
        const _FakeProcessor('a'),
        const _FakeProcessor('b'),
        const _FakeProcessor('c'),
      ];

      expect(
        _ids(resolveExecutionPlan(processors, requested: ['c', 'a', 'b'])),
        ['a', 'b', 'c'],
      );
    });

    test('breaks ties by id whatever the order of the input', () {
      final processors = [
        const _FakeProcessor('d', dependsOn: {'a'}),
        const _FakeProcessor('c', dependsOn: {'a'}),
        const _FakeProcessor('b', dependsOn: {'a'}),
        const _FakeProcessor('a'),
      ];

      for (final input in [processors, processors.reversed.toList()]) {
        expect(
          _ids(resolveExecutionPlan(input, requested: ['d', 'c', 'b'])),
          ['a', 'b', 'c', 'd'],
        );
      }
    });

    test('plans nothing when nothing is requested', () {
      final plan = resolveExecutionPlan([
        const _FakeProcessor('a'),
      ], requested: const []);

      expect(plan.steps, isEmpty);
    });
  });
}
