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
import 'package:flutter_flavorizr/src/engine/recipe/closest_match.dart';
import 'package:flutter_flavorizr/src/exception/invalid_recipe_name_exception.dart';
import 'package:flutter_flavorizr/src/exception/recipe_cycle_exception.dart';
import 'package:flutter_flavorizr/src/exception/unknown_target_exception.dart';

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
///
/// A recipe is a named list of processor ids and other recipes. A target is
/// the name of a recipe or the id of a processor, and the two never share a
/// name. Everything that can be wrong with the names is reported when the
/// catalog is built or when targets are resolved, before anything runs.
class RecipeCatalog {
  final Set<String> _processorIds;
  final Map<String, List<String>> _recipes;
  final String _defaultTarget;

  /// Creates the catalog of the recipes that can be run over [processorIds].
  ///
  /// [recipes] are the recipes of the user. [defaultRecipe] names the one run
  /// when no target is given; without it the recipe called `default` is used
  /// when the user defined it, and `all` otherwise.
  ///
  /// Throws an [InvalidRecipeNameException] when a recipe is named like a
  /// command, a built-in recipe or a processor, an [UnknownTargetException]
  /// when a recipe contains, or [defaultRecipe] names, something that is
  /// neither a recipe nor a processor, and a [RecipeCycleException] when
  /// recipes contain each other in a cycle.
  factory RecipeCatalog({
    required Iterable<String> processorIds,
    Map<String, List<String>> recipes = const {},
    String? defaultRecipe,
  }) {
    final ids = processorIds.toSet();

    for (final name in _sorted(recipes.keys)) {
      if (reservedRecipeNames.contains(name)) {
        throw InvalidRecipeNameException(name, 'it is the name of a command');
      }
      if (builtInRecipes.containsKey(name)) {
        throw InvalidRecipeNameException(
          name,
          'it is the name of a built-in recipe',
        );
      }
      if (ids.contains(name)) {
        throw InvalidRecipeNameException(
          name,
          'it is the id of a processor',
        );
      }
    }

    final catalog = RecipeCatalog._(
      ids,
      {
        for (final entry in builtInRecipes.entries)
          entry.key: [
            for (final member in entry.value)
              if (ids.contains(member) || builtInRecipes.containsKey(member))
                member,
          ],
        for (final entry in recipes.entries)
          entry.key: List.unmodifiable(entry.value),
      },
      defaultRecipe ??
          (recipes.containsKey(defaultRecipeName)
              ? defaultRecipeName
              : allRecipeName),
    );

    for (final name in _sorted(recipes.keys)) {
      for (final member in recipes[name]!) {
        catalog._requireKnown(member, recipe: name);
      }
    }
    if (defaultRecipe != null) {
      catalog._requireKnown(defaultRecipe);
    }
    catalog._requireNoCycle(recipes.keys);

    return catalog;
  }

  const RecipeCatalog._(this._processorIds, this._recipes, this._defaultTarget);

  /// Resolves [targets] to the processor ids they stand for.
  ///
  /// Without targets, the default recipe is resolved. Every target is checked
  /// before any is expanded.
  ///
  /// Throws an [UnknownTargetException] when a target is neither a recipe nor
  /// a processor.
  ///
  /// [platformsWithoutFlavors] holds the platforms (see [platformRecipes]) the
  /// project has no flavors for. Their recipes and processors are left out,
  /// with a message, the same way the instructions of a platform without
  /// flavors have always been dropped: a processor is dropped when the
  /// namespace of its id, the part before the first `:`, is one of them.
  RecipeResolution resolve(
    List<String> targets, {
    Set<String> platformsWithoutFlavors = const {},
  }) {
    final requested = targets.isEmpty ? [_defaultTarget] : targets;
    for (final target in requested) {
      _requireKnown(target);
    }

    final ids = <String>{};
    final messages = <String>{};

    bool skipped(String name, String platform) {
      if (!platformsWithoutFlavors.contains(platform)) {
        return false;
      }
      messages.add(
        'Skipping "$name": no flavors are configured for $platform.',
      );

      return true;
    }

    void expand(String name) {
      final members = _recipes[name];
      if (members == null) {
        if (!skipped(name, name.split(':').first)) {
          ids.add(name);
        }
      } else if (!platformRecipes.contains(name) || !skipped(name, name)) {
        members.forEach(expand);
      }
    }

    requested.forEach(expand);

    return RecipeResolution(
      ids.toList(growable: false),
      messages: messages.toList(growable: false),
    );
  }

  void _requireKnown(String name, {String? recipe}) {
    if (_recipes.containsKey(name) || _processorIds.contains(name)) {
      return;
    }

    throw UnknownTargetException(
      name,
      recipe: recipe,
      suggestion: closestMatch(name, [..._recipes.keys, ..._processorIds]),
    );
  }

  /// Throws a [RecipeCycleException] when the [names] recipes, or the ones
  /// they contain, contain each other in a cycle.
  ///
  /// The search starts from the names in sorted order and follows members in
  /// declaration order, so the same recipes always report the same cycle.
  void _requireNoCycle(Iterable<String> names) {
    final visiting = <String>[];
    final finished = <String>{};

    void visit(String name) {
      visiting.add(name);
      for (final member in _recipes[name]!.where(_recipes.containsKey)) {
        final start = visiting.indexOf(member);
        if (start != -1) {
          throw RecipeCycleException([...visiting.sublist(start), member]);
        }
        if (!finished.contains(member)) {
          visit(member);
        }
      }
      visiting.removeLast();
      finished.add(name);
    }

    for (final name in _sorted(names)) {
      if (!finished.contains(name)) {
        visit(name);
      }
    }
  }
}

/// A sorted copy of [names], so that no iteration depends on the order of the
/// input.
List<String> _sorted(Iterable<String> names) => names.toList()..sort();
