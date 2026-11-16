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

/// What a list of targets resolves to.
final class RecipeResolution {
  /// The processor ids to run, without duplicates, in the order the targets
  /// list them. The execution plan orders them for real.
  final List<String> processorIds;

  /// What was left out and why, ready to be shown as info messages.
  final List<String> messages;

  /// Creates a resolution.
  const RecipeResolution(this.processorIds, {this.messages = const []});
}

/// The recipes of a run: the built-in ones plus the ones of the user.
class RecipeCatalog {
  final Map<String, List<String>> _recipes;
  final String _defaultTarget;

  /// Creates the catalog of the recipes that can be run over [processorIds].
  ///
  /// [recipes] are the recipes of the user. [defaultRecipe] names the one run
  /// when no target is given; without it the recipe called `default` is used
  /// when the user defined it, and `all` otherwise.
  RecipeCatalog({
    required Iterable<String> processorIds,
    Map<String, List<String>> recipes = const {},
    String? defaultRecipe,
  }) : this._(
         processorIds.toSet(),
         recipes,
         defaultRecipe ??
             (recipes.containsKey(defaultRecipeName)
                 ? defaultRecipeName
                 : allRecipeName),
       );

  RecipeCatalog._(
    Set<String> processorIds,
    Map<String, List<String>> recipes,
    this._defaultTarget,
  ) : _recipes = {
        for (final entry in builtInRecipes.entries)
          entry.key: [
            for (final member in entry.value)
              if (processorIds.contains(member) ||
                  builtInRecipes.containsKey(member))
                member,
          ],
        ...recipes,
      };

  /// Resolves [targets] to the processor ids they stand for.
  ///
  /// Without targets, the default recipe is resolved.
  RecipeResolution resolve(List<String> targets) {
    final ids = <String>{};

    void expand(String name) {
      final members = _recipes[name];
      if (members == null) {
        ids.add(name);
        return;
      }
      members.forEach(expand);
    }

    (targets.isEmpty ? [_defaultTarget] : targets).forEach(expand);

    return RecipeResolution(ids.toList(growable: false));
  }
}
