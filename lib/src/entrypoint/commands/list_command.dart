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

import 'package:flutter_flavorizr/src/engine/flavorizr_processor.dart';
import 'package:flutter_flavorizr/src/engine/recipe/recipe_catalog.dart';
import 'package:flutter_flavorizr/src/entrypoint/commands/flavorizr_command.dart';
import 'package:flutter_flavorizr/src/entrypoint/exit_codes.dart';
import 'package:flutter_flavorizr/src/entrypoint/output/documents.dart';

/// `flavorizr list`: the recipes and the processors, with what each one needs.
class ListCommand extends FlavorizrCommand {
  /// Creates the command.
  ListCommand(super.context) {
    addJsonFlag();
  }

  @override
  String get name => 'list';

  @override
  String get description =>
      'Lists the recipes, the built-in ones and the ones of flavorizr.yaml, '
      'and the processors with the ones they depend on and where they run.';

  @override
  Future<int> execute() async {
    // A project without configuration still has processors to list, one whose
    // configuration is broken has not.
    final config = loadConfigIfPresent();
    final registry = context.registry;
    final catalog = RecipeCatalog(
      processorIds: registry.ids,
      recipes: config?.recipes ?? const {},
      defaultRecipe: config?.defaultRecipe,
    );
    final processors = registry.engineProcessors;

    output.data({
      'recipes': recipeFields(catalog.listing()),
      'processors': listedProcessorFields(
        ids: registry.ids,
        engine: processors,
      ),
    });

    output.info('Recipes\n${catalog.renderListing()}');
    output.info(
      'Processors (engine: previewed, checked against the lock and written '
      'atomically; legacy: applied straight to the project)',
    );

    for (final id in (registry.ids.toList()..sort())) {
      final processor = processors[id];

      output.info(
        '  $id [${processor == null ? 'legacy' : 'engine'}]${_tree(processor)}',
      );
    }

    return ExitCodes.ok;
  }

  /// The dependencies of [processor], as the branches of its tree.
  String _tree(FlavorizrProcessor? processor) {
    if (processor == null) return '';

    final dependencies = <(String, String)>[
      for (final id in processor.dependsOn.toList()..sort()) ('needs', id),
      for (final id in processor.after.toList()..sort()) ('after', id),
    ];

    return [
      for (var index = 0; index < dependencies.length; index++)
        '\n    ${index == dependencies.length - 1 ? '└─' : '├─'} '
            '${dependencies[index].$1} ${_describe(dependencies[index].$2)}',
    ].join();
  }

  String _describe(String id) =>
      '$id${context.registry.isEngine(id) ? '' : ' (legacy)'}';
}
