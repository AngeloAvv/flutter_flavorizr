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
import 'package:flutter_flavorizr/src/engine/shadow/workspace_diff.dart';
import 'package:flutter_flavorizr/src/entrypoint/engine_runner.dart';
import 'package:flutter_flavorizr/src/entrypoint/run_plan.dart';

/// The processors of [plan] as text: the ones of the engine in the order they
/// run, with the ones pulled in by a dependency marked `(auto)`, then the ones
/// the legacy pipeline runs, which cannot be previewed.
String renderRunPlan(RunPlan plan) {
  final steps = plan.engine.steps;

  return [
    if (steps.isNotEmpty)
      'Processors on the engine, in order:\n'
          '${[for (var index = 0; index < steps.length; index++) '  ${index + 1}. ${steps[index].processor.id}'
                '${steps[index].auto ? ' (auto)' : ''}'].join('\n')}',
    if (plan.legacy.isNotEmpty)
      'Processors not on the engine yet, applied straight to the project '
          'afterwards, with no preview and no conflict detection:\n'
          '${[for (final step in plan.legacy) '  - ${step.id}'].join('\n')}',
    if (plan.isEmpty) 'There is nothing to run.',
  ].join('\n\n');
}

/// What [preview] would change, as text: the flavors that changed, then the
/// files, grouped by platform, as `+` (added), `~` (changed) and `-` (deleted),
/// and a count.
String renderPreview(EnginePreview preview) {
  final groups = <String, List<FileChange>>{};

  for (final change in preview.changes) {
    groups.putIfAbsent(platformOf(change.path), () => []).add(change);
  }

  final names = groups.keys.toList()..sort();
  final conflicts = preview.diff.conflicts.length;
  final counts = [
    for (final (symbol, kind) in [
      ('to add', ChangeKind.added),
      ('to change', ChangeKind.modified),
      ('to delete', ChangeKind.deleted),
    ])
      '${preview.changes.where((c) => c.kind == kind && c.disposition == ChangeDisposition.apply).length} $symbol',
    '$conflicts ${conflicts == 1 ? 'conflict' : 'conflicts'}',
  ];

  return [
    preview.reconciliation.flavors.render(),
    if (names.isEmpty)
      'The files of the project are up to date.'
    else ...[
      for (final name in names)
        '$name\n${[for (final change in groups[name]!) '  ${change.describe()}'].join('\n')}',
      counts.join(', '),
    ],
    if (preview.reconciliation.deletions.released.isNotEmpty)
      'Left in place (shared with you, no longer owned by flavorizr):\n'
          '${[for (final stale in preview.reconciliation.deletions.released) '  - ${stale.path}'].join('\n')}',
    if (preview.reconciliation.invalid.isNotEmpty)
      'Ignored in the lock (not a path of the project):\n'
          '${[for (final path in preview.reconciliation.invalid) '  - ${path.path} (${path.processorId})'].join('\n')}',
  ].where((section) => section.isNotEmpty).join('\n\n');
}

/// The platform a file of the project belongs to, which is how a preview
/// groups its files: the folder of a platform, `flutter` for the Dart sources
/// and `project` for anything else.
String platformOf(String path) {
  final root = path.split('/').first;

  if (platformRecipes.contains(root)) return root;

  return root == 'lib' ? 'flutter' : 'project';
}
