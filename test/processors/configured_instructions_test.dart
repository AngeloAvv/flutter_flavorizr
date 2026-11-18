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

import 'package:flutter_flavorizr/src/engine/recipe/built_in_recipes.dart';
import 'package:flutter_flavorizr/src/entrypoint/processor_registry.dart';
import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:flutter_test/flutter_test.dart';

/// The configurations of the repository that CI feeds to a run. Since a run
/// stops at an unknown instruction, a stale one fails the build.
const _configurations = [
  'blank/flavorizr.yaml',
  'example/flavorizr.yaml',
  'tool/parity/fixtures/flavorizr.3.yaml',
];

void main() {
  final registry = ProcessorRegistry.standard();

  for (final path in _configurations) {
    test(
      '$path only lists instructions that are processors in its default recipe',
      () {
        final config = Flavorizr.parse(File(path).readAsStringSync());
        final instructions = config.recipes?['default'] ?? const <String>[];

        expect(
          instructions.where(
            (instruction) =>
                !registry.ids.contains(instruction) &&
                !builtInRecipes.containsKey(instruction),
          ),
          isEmpty,
        );
      },
    );
  }
}
