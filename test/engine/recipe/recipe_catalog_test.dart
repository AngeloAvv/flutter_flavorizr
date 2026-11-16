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

import 'package:flutter_flavorizr/src/engine/recipe/built_in_recipes.dart';
import 'package:flutter_flavorizr/src/engine/recipe/recipe_catalog.dart';
import 'package:flutter_flavorizr/src/processors/processor.dart';
import 'package:flutter_test/flutter_test.dart';

/// The processor ids that exist today.
const _ids = Processor.defaultInstructionSet;

RecipeCatalog _catalog({
  Map<String, List<String>> recipes = const {},
  String? defaultRecipe,
  Iterable<String> processorIds = _ids,
}) => RecipeCatalog(
  processorIds: processorIds,
  recipes: recipes,
  defaultRecipe: defaultRecipe,
);

void main() {
  group('built-in recipes', () {
    test('a platform recipe expands to the processors of that platform', () {
      final resolution = _catalog().resolve(['linux']);

      expect(resolution.processorIds, [
        'linux:cmake',
        'linux:runnerCmake',
        'linux:myApplication',
      ]);
    });

    test('all expands to the whole legacy instruction set, in order', () {
      final resolution = _catalog().resolve(['all']);

      expect(resolution.processorIds, _ids);
    });

    test('cross-platform recipes group processors of several platforms', () {
      final catalog = _catalog();

      expect(catalog.resolve(['icons']).processorIds, [
        'android:icons',
        'ios:icons',
        'macos:icons',
        'windows:icons',
      ]);
      expect(catalog.resolve(['firebase']).processorIds, ['google:firebase']);
      expect(catalog.resolve(['ide']).processorIds, ['ide:config']);
      expect(catalog.resolve(['flutter']).processorIds, [
        'flutter:flavors',
        'flutter:app',
        'flutter:pages',
        'flutter:main',
      ]);
    });

    test('every member of a built-in recipe is a known processor or recipe', () {
      for (final entry in builtInRecipes.entries) {
        for (final member in entry.value) {
          expect(
            _ids.contains(member) || builtInRecipes.containsKey(member),
            isTrue,
            reason: '${entry.key} names unknown member $member',
          );
        }
      }
    });

    test('a member that matches no available processor is ignored', () {
      final catalog = _catalog(processorIds: ['linux:cmake']);

      expect(catalog.resolve(['linux']).processorIds, ['linux:cmake']);
    });
  });

  group('targets', () {
    test('a processor id is a target of its own', () {
      final resolution = _catalog().resolve(['ios:plist']);

      expect(resolution.processorIds, ['ios:plist']);
    });

    test('targets are merged without duplicates, first mention wins', () {
      final resolution = _catalog().resolve(['ios:plist', 'icons', 'ios']);

      expect(resolution.processorIds.where((id) => id == 'ios:plist'), [
        'ios:plist',
      ]);
      expect(resolution.processorIds.first, 'ios:plist');
      expect(resolution.processorIds.toSet().length, resolution.processorIds.length);
    });

    test('no target runs all', () {
      final resolution = _catalog().resolve([]);

      expect(resolution.processorIds, _ids);
    });

    test('no target runs the default recipe when the user defines one', () {
      final catalog = _catalog(
        recipes: {
          'default': ['linux'],
        },
      );

      expect(catalog.resolve([]).processorIds, [
        'linux:cmake',
        'linux:runnerCmake',
        'linux:myApplication',
      ]);
    });

    test('no target runs the recipe named as default', () {
      final catalog = _catalog(
        recipes: {
          'ci': ['ios:plist'],
        },
        defaultRecipe: 'ci',
      );

      expect(catalog.resolve([]).processorIds, ['ios:plist']);
    });
  });
}
