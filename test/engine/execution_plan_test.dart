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
import 'package:flutter_flavorizr/src/exception/dependency_cycle_exception.dart';
import 'package:flutter_flavorizr/src/exception/duplicate_processor_exception.dart';
import 'package:flutter_flavorizr/src/exception/unknown_processor_exception.dart';
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
          const _FakeProcessor(
            'android:buildGradle',
            dependsOn: {'android:flavorizrGradle'},
          ),
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

      expect(_ids(resolveExecutionPlan(processors, requested: ['a', 'b'])), [
        'b',
        'a',
      ]);
    });

    test('never pulls in a processor through after', () {
      final plan = resolveExecutionPlan(
        [
          const _FakeProcessor('a', after: {'b'}),
          const _FakeProcessor('b'),
        ],
        requested: ['a'],
      );

      expect(_ids(plan), ['a']);
    });

    test('ignores an after that points at an unknown id', () {
      final plan = resolveExecutionPlan(
        [
          const _FakeProcessor('a', after: {'ghost'}),
        ],
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
        expect(_ids(resolveExecutionPlan(input, requested: ['d', 'c', 'b'])), [
          'a',
          'b',
          'c',
          'd',
        ]);
      }
    });

    test('plans nothing when nothing is requested', () {
      final plan = resolveExecutionPlan([
        const _FakeProcessor('a'),
      ], requested: const []);

      expect(plan.steps, isEmpty);
    });

    group('unknown processors', () {
      test('rejects a requested id that matches no processor', () {
        expect(
          () => resolveExecutionPlan(
            [const _FakeProcessor('a')],
            requested: ['ghost'],
          ),
          throwsA(
            isA<UnknownProcessorException>()
                .having((e) => e.id, 'id', 'ghost')
                .having((e) => e.requiredBy, 'requiredBy', isNull),
          ),
        );
      });

      test('names the processor whose dependsOn points at an unknown id', () {
        expect(
          () => resolveExecutionPlan(
            [
              const _FakeProcessor('a', dependsOn: {'b'}),
              const _FakeProcessor('b', dependsOn: {'ghost'}),
            ],
            requested: ['a'],
          ),
          throwsA(
            isA<UnknownProcessorException>()
                .having((e) => e.id, 'id', 'ghost')
                .having((e) => e.requiredBy, 'requiredBy', 'b')
                .having(
                  (e) => e.toString(),
                  'message',
                  allOf(contains('ghost'), contains('b')),
                ),
          ),
        );
      });

      test('ignores a broken dependsOn of a processor outside the plan', () {
        final plan = resolveExecutionPlan(
          [
            const _FakeProcessor('a'),
            const _FakeProcessor('b', dependsOn: {'ghost'}),
          ],
          requested: ['a'],
        );

        expect(_ids(plan), ['a']);
      });
    });

    group('duplicated ids', () {
      test('rejects two processors with the same id', () {
        expect(
          () => resolveExecutionPlan(
            [const _FakeProcessor('a'), const _FakeProcessor('a')],
            requested: ['a'],
          ),
          throwsA(
            isA<DuplicateProcessorException>().having((e) => e.id, 'id', 'a'),
          ),
        );
      });
    });

    group('cycles', () {
      Matcher cycleOf(List<String> cycle) => throwsA(
        isA<DependencyCycleException>().having((e) => e.cycle, 'cycle', cycle),
      );

      test('rejects a processor that depends on itself', () {
        expect(
          () => resolveExecutionPlan(
            [
              const _FakeProcessor('a', dependsOn: {'a'}),
            ],
            requested: ['a'],
          ),
          cycleOf(['a', 'a']),
        );
      });

      test('rejects a processor that must run after itself', () {
        expect(
          () => resolveExecutionPlan(
            [
              const _FakeProcessor('a', after: {'a'}),
            ],
            requested: ['a'],
          ),
          cycleOf(['a', 'a']),
        );
      });

      test('shows the path of a cycle through dependsOn', () {
        expect(
          () => resolveExecutionPlan(
            [
              const _FakeProcessor('a', dependsOn: {'b'}),
              const _FakeProcessor('b', dependsOn: {'c'}),
              const _FakeProcessor('c', dependsOn: {'a'}),
            ],
            requested: ['a'],
          ),
          cycleOf(['a', 'b', 'c', 'a']),
        );
      });

      test('reports only the cycle, not the processors leading to it', () {
        expect(
          () => resolveExecutionPlan(
            [
              const _FakeProcessor('entry', dependsOn: {'b'}),
              const _FakeProcessor('b', dependsOn: {'c'}),
              const _FakeProcessor('c', dependsOn: {'b'}),
            ],
            requested: ['entry'],
          ),
          cycleOf(['b', 'c', 'b']),
        );
      });

      test('detects a cycle closed by an after between planned processors', () {
        expect(
          () => resolveExecutionPlan(
            [
              const _FakeProcessor('a', dependsOn: {'b'}),
              const _FakeProcessor('b', after: {'a'}),
            ],
            requested: ['a'],
          ),
          cycleOf(['a', 'b', 'a']),
        );
      });

      test('ignores a cycle that only exists through an absent after', () {
        // With `a` in the plan, `c -> d -> a -> c` would be a cycle; but
        // nothing pulls `a` in, so its `after` edges do not count.
        final plan = resolveExecutionPlan(
          [
            const _FakeProcessor('a', after: {'c'}),
            const _FakeProcessor('c', dependsOn: {'d'}),
            const _FakeProcessor('d', after: {'a'}),
          ],
          requested: ['c'],
        );

        expect(_ids(plan), ['d', 'c']);
      });

      test('ignores a cycle among processors that are not in the plan', () {
        final plan = resolveExecutionPlan(
          [
            const _FakeProcessor('a'),
            const _FakeProcessor('x', dependsOn: {'y'}),
            const _FakeProcessor('y', dependsOn: {'x'}),
          ],
          requested: ['a'],
        );

        expect(_ids(plan), ['a']);
      });

      test('reports the same cycle whatever the order of the input', () {
        final processors = [
          const _FakeProcessor('a', dependsOn: {'b', 'c'}),
          const _FakeProcessor('b', dependsOn: {'a'}),
          const _FakeProcessor('c', dependsOn: {'a'}),
        ];

        for (final input in [processors, processors.reversed.toList()]) {
          expect(
            () => resolveExecutionPlan(input, requested: ['c', 'b', 'a']),
            cycleOf(['a', 'b', 'a']),
          );
        }
      });

      test('names the cycle path in the message', () {
        expect(
          () => resolveExecutionPlan(
            [
              const _FakeProcessor('a', dependsOn: {'b'}),
              const _FakeProcessor('b', dependsOn: {'a'}),
            ],
            requested: ['a'],
          ),
          throwsA(
            isA<DependencyCycleException>().having(
              (e) => e.toString(),
              'message',
              contains('a -> b -> a'),
            ),
          ),
        );
      });
    });
  });
}
