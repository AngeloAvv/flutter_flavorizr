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

import 'package:flutter_flavorizr/src/entrypoint/processor_registry.dart';
import 'package:flutter_flavorizr/src/entrypoint/run_plan.dart';
import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:test/test.dart';

String _config(String root) =>
    '''
${root}flavors:
  apple:
    app:
      name: "Apple"
    ios:
      bundleId: "com.example.apple"
''';

void main() {
  final registry = ProcessorRegistry.standard();

  group('a full run', () {
    test('has no launch screen to make when no flavor has one', () {
      final ids = engineIdsFor(registry, FlavorizrConfig.parse(_config('')));

      expect(ids, contains('ios:xcconfig'));
      expect(ids, isNot(contains('ios:launchScreen')));
    });

    test('has to cover it when a flavor has one', () {
      final ids = engineIdsFor(
        registry,
        FlavorizrConfig.parse(_config('launchScreen: true\n')),
      );

      expect(ids, contains('ios:launchScreen'));
    });
  });
}
