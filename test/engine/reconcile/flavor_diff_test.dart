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

import 'package:flutter_flavorizr/src/engine/reconcile/flavor_diff.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('diffFlavors', () {
    test('everything is added on the first run', () {
      final diff = diffFlavors(
        desired: {'dev': 'h1', 'prod': 'h2'},
        applied: {},
      );

      expect(diff.added, ['dev', 'prod']);
      expect(diff.removed, isEmpty);
      expect(diff.changed, isEmpty);
      expect(diff.unchanged, isEmpty);
    });

    test('tells added, removed, changed and unchanged flavors apart', () {
      final diff = diffFlavors(
        desired: {'dev': 'h1', 'stage': 'h9', 'beta': 'h4'},
        applied: {'dev': 'h1', 'stage': 'h2', 'prod': 'h3'},
      );

      expect(diff.added, ['beta']);
      expect(diff.removed, ['prod']);
      expect(diff.changed, ['stage']);
      expect(diff.unchanged, ['dev']);
      expect(diff.isEmpty, isFalse);
    });

    test('is empty when nothing differs', () {
      final diff = diffFlavors(desired: {'dev': 'h1'}, applied: {'dev': 'h1'});

      expect(diff.isEmpty, isTrue);
      expect(diff.render(), 'No flavor changes.');
    });

    test('a rename is a removal plus an addition, and the plan says so', () {
      final diff = diffFlavors(
        desired: {'staging': 'h1'},
        applied: {'stage': 'h1'},
      );

      expect(diff.removed, ['stage']);
      expect(diff.added, ['staging']);
      expect(diff.renamed, {'stage': 'staging'});
      expect(
        diff.render(),
        '- stage (removed)\n'
        '+ staging (added)\n'
        'stage -> staging is a rename: it is applied as the removal of '
        '`stage` plus the addition of `staging`.',
      );
    });

    test('a removal next to an unrelated addition is not called a rename', () {
      final diff = diffFlavors(
        desired: {'beta': 'h2'},
        applied: {'prod': 'h1'},
      );

      expect(diff.renamed, isEmpty);
      expect(diff.render(), '- prod (removed)\n+ beta (added)');
    });

    test('an ambiguous hash is never paired', () {
      final diff = diffFlavors(
        desired: {'a2': 'h', 'b2': 'h'},
        applied: {'a': 'h'},
      );

      expect(diff.renamed, isEmpty);
    });
  });
}
