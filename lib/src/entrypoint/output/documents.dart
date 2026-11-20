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

import 'package:flutter_flavorizr/src/engine/conflict/conflict_resolver.dart';
import 'package:flutter_flavorizr/src/engine/execution_report.dart';
import 'package:flutter_flavorizr/src/engine/flavorizr_processor.dart';
import 'package:flutter_flavorizr/src/engine/recipe/recipe_listing.dart';
import 'package:flutter_flavorizr/src/engine/shadow/workspace_diff.dart';
import 'package:flutter_flavorizr/src/entrypoint/engine_runner.dart';
import 'package:flutter_flavorizr/src/entrypoint/output/output.dart';
import 'package:flutter_flavorizr/src/entrypoint/plan_report.dart';
import 'package:flutter_flavorizr/src/entrypoint/run_plan.dart';

/// The fields of the JSON documents of `plan`, `apply`, `status` and `list`.
///
/// The documents are the contract of `--json`: `doc/json-output.md` describes
/// them and `doc/schemas/flavorizr-output.schema.json` validates them. A field
/// is never removed, renamed or given another type before 4.0.

/// How [preview] changes the files: what a run would add, change and delete,
/// and the changes it would lose something edited by hand with.
///
/// With the [resolution] of a run that wrote, it is what was written: the
/// conflicts that were overwritten count as the changes they are, and the ones
/// that were kept are the conflicts left.
ChangeCounts countChanges(
  EnginePreview? preview, {
  ConflictResolution? resolution,
}) {
  if (preview == null) return const ChangeCounts();

  final written = [
    for (final change in preview.changes)
      if (change.disposition == ChangeDisposition.apply ||
          (resolution?.approved.contains(change.path) ?? false))
        change,
  ];

  int count(ChangeKind kind) =>
      written.where((change) => change.kind == kind).length;

  return ChangeCounts(
    added: count(ChangeKind.added),
    modified: count(ChangeKind.modified),
    deleted: count(ChangeKind.deleted),
    conflicts: resolution == null
        ? preview.diff.conflicts.length
        : resolution.kept.length,
  );
}

/// What [plan] runs: the processors in the order they run, with the ones a
/// dependency pulled in marked `auto`. [plan] also says what it left out and
/// why.
Map<String, Object?> processorFields(RunPlan plan) => {
  'messages': plan.messages,
  'processors': [
    for (final step in plan.engine.steps)
      {
        'id': step.processor.id,
        'platform': platformOfProcessor(step.processor.id),
        'runsOn': 'engine',
        'auto': step.auto,
      },
  ],
};

/// What [preview] would change: the flavors, and the files, by path. A project
/// with no processor on the engine has no [preview], and nothing to change.
Map<String, Object?> previewFields(EnginePreview? preview) => {
  'flavors': {
    'added': preview?.reconciliation.flavors.added ?? const <String>[],
    'removed': preview?.reconciliation.flavors.removed ?? const <String>[],
    'changed': preview?.reconciliation.flavors.changed ?? const <String>[],
  },
  'changes': [
    for (final change in preview?.changes ?? const <FileChange>[])
      {
        'path': change.path,
        'platform': platformOf(change.path),
        'change': change.kind.name,
        'disposition': change.disposition.name,
        'ownership': change.ownership?.name,
      },
  ],
  'summary': countChanges(preview).toJson(),
};

/// What happened to the processors of a run: the ones that ran, in order, with
/// how long each took and whether it completed or failed, then the ones that
/// did not run because an earlier one failed, or the run stopped: the ones the
/// [report] skipped, and the [planned] ones nothing recorded.
List<Map<String, Object?>> stepFields(
  ExecutionReport? report,
  List<StepRecord> records, {
  Iterable<String> planned = const [],
}) {
  final skipped = {
    ...?report?.skipped,
    ...planned.where((id) => !records.any((record) => record.id == id)),
  };

  return [
    for (final record in records)
      {
        'id': record.id,
        'status': record.status.name,
        'durationMs': record.elapsed.inMilliseconds,
      },
    for (final id in skipped)
      {'id': id, 'status': 'skipped', 'durationMs': null},
  ];
}

/// The recipes of `list`, as they are shown.
List<Map<String, Object?>> recipeFields(Iterable<RecipeListing> recipes) => [
  for (final recipe in recipes)
    {
      'name': recipe.name,
      'builtIn': recipe.builtIn,
      'default': recipe.isDefault,
      'members': recipe.members,
      'processors': recipe.expansion,
    },
];

/// The processors of `list`: what each one needs.
List<Map<String, Object?>> listedProcessorFields({
  required Iterable<String> ids,
  required Map<String, FlavorizrProcessor> engine,
  Set<String> overridden = const {},
}) => [
  for (final id in ids.toList()..sort())
    {
      'id': id,
      'platform': platformOfProcessor(id),
      'runsOn': 'engine',
      'needs': _sorted(engine[id]?.dependsOn),
      'after': _sorted(engine[id]?.after),
      'overridden': overridden.contains(id),
    },
];

List<String> _sorted(Set<String>? ids) => (ids?.toList() ?? [])..sort();
