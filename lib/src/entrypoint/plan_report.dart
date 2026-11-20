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
import 'package:flutter_flavorizr/src/entrypoint/adopt_runner.dart';
import 'package:flutter_flavorizr/src/entrypoint/engine_runner.dart';
import 'package:flutter_flavorizr/src/entrypoint/output/style.dart';
import 'package:flutter_flavorizr/src/entrypoint/run_plan.dart';

/// The processors of [plan] as text, in the order they run, with the ones pulled
/// in by a dependency marked `(auto)`.
String renderRunPlan(RunPlan plan) {
  final steps = plan.engine.steps;

  return [
    if (steps.isNotEmpty)
      'Processors on the engine, in order:\n'
          '${[for (var index = 0; index < steps.length; index++) '  ${index + 1}. ${steps[index].processor.id}'
                '${steps[index].auto ? ' (auto)' : ''}'].join('\n')}',
    if (plan.isEmpty) 'There is nothing to run.',
  ].join('\n\n');
}

/// What [preview] would change, as text: the flavors that changed, then the
/// files, grouped by platform, as `+` (added), `~` (changed) and `-` (deleted),
/// and a count.
///
/// The changes are coloured as a diff with [style]: green for what is added,
/// yellow for what changes, red for what is deleted or in conflict. It changes
/// no word of the text.
String renderPreview(
  EnginePreview preview, {
  Style style = const Style.none(),
}) {
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
    style.diff(preview.reconciliation.flavors.render()),
    if (names.isEmpty)
      'The files of the project are up to date.'
    else ...[
      for (final name in names)
        '${style.bold(name)}\n${[for (final change in groups[name]!) '  ${style.change(change)}'].join('\n')}',
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

/// What to tell when a run adopted the project first (see
/// `FirstRunAdoption`): there is no `flavorizr.lock`, and the files that tell
/// flavorizr made them before are taken as the baseline.
///
/// With [writes], the run is one that writes (`apply`), which puts the baseline
/// in the lock with its changes. Without it the run is a dry one, and `flavorizr
/// adopt` is what records the baseline.
String renderAdoptionNotice(FirstRunAdoption adopted, {required bool writes}) {
  const shown = 3;
  final evidence = adopted.evidence;
  final others = evidence.length - shown;
  final files =
      '${evidence.take(shown).join(', ')}'
      '${others > 0 ? ' and $others more' : ''}';

  return 'There is no flavorizr.lock, and the project has files flavorizr made '
      'before there was one ($files). They are taken as the baseline, so that '
      'what follows is what 3.x changes in them. '
      '${adopted.partial ? 'A processor of the default recipe could not read the project, so only the ones of this run were adopted, and the files of the others have no baseline. ' : ''}'
      '${writes ? 'The lock is written with the changes, once you approve them: nothing is written otherwise.' : 'Nothing is written: `flavorizr adopt` records the baseline, and `flavorizr apply` does too, with its changes.'}';
}

/// The platform a file of the project belongs to, which is how a preview
/// groups its files: the folder of a platform, `flutter` for the Dart sources
/// and `project` for anything else.
String platformOf(String path) {
  final root = path.split('/').first;

  if (platformRecipes.contains(root)) return root;

  return root == 'lib' ? 'flutter' : 'project';
}
