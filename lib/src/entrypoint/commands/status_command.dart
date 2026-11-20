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

import 'package:flutter_flavorizr/src/engine/ownership.dart';
import 'package:flutter_flavorizr/src/entrypoint/commands/flavorizr_command.dart';
import 'package:flutter_flavorizr/src/entrypoint/exit_codes.dart';
import 'package:flutter_flavorizr/src/entrypoint/output/documents.dart';
import 'package:flutter_flavorizr/src/entrypoint/plan_report.dart';

/// `flavorizr status [target...]`: whether `flavorizr.yaml`, `flavorizr.lock`
/// and the files of the project agree. It is meant for CI.
class StatusCommand extends TargetCommand {
  /// Creates the command.
  StatusCommand(super.context);

  @override
  String get name => 'status';

  @override
  String get description =>
      'Tells whether flavorizr.yaml, flavorizr.lock and the files of the '
      'project agree, and exits with 1 when they drifted apart, so that a CI '
      'can check it. Nothing is written.';

  @override
  String get invocation => '${runner!.executableName} status [target...]';

  @override
  Future<int> execute() async {
    final config = loadConfig();
    final plan = resolve(config);
    final preview = await dryRun(plan, config);
    final drift = <_Drift>[];

    if (preview != null) {
      if (preview.previous == null) {
        drift.add(
          const _Drift(
            'lock',
            'flavorizr.lock does not exist: nothing is recorded as applied.',
          ),
        );
      } else if (preview.adopted case final adopted?) {
        drift.add(
          _Drift(
            'lock',
            'flavorizr.lock does not exist: nothing is recorded as applied. '
                '${renderAdoptionNotice(adopted, writes: false)}',
          ),
        );
      }

      if (!preview.reconciliation.flavors.isEmpty) {
        drift.add(
          _Drift(
            'flavors',
            'The flavors of flavorizr.yaml and of flavorizr.lock differ:\n'
                '${output.style.diff(preview.reconciliation.flavors.render())}',
          ),
        );
      }

      // A local file, such as the run configurations of an IDE, is written again
      // silently on every run: it is never drift, a fresh clone has none.
      final pending = preview.changes
          .where(
            (c) =>
                !preview.diff.conflicts.contains(c) &&
                c.ownership != Ownership.local,
          )
          .toList();
      if (pending.isNotEmpty) {
        drift.add(
          _Drift(
            'files',
            'These files are not what flavorizr.yaml asks for:\n'
                '${[for (final change in pending) '  ${output.style.change(change)}'].join('\n')}',
            [for (final change in pending) change.path],
          ),
        );
      }

      if (preview.hasConflicts) {
        drift.add(
          _Drift(
            'edited',
            'These files were edited by hand:\n'
                '${[for (final change in preview.diff.conflicts) '  ${output.style.change(change)}'].join('\n')}',
            [for (final change in preview.diff.conflicts) change.path],
          ),
        );
      }
    }

    final checked = plan.engine.steps.isNotEmpty;

    output.data({
      ...previewFields(preview),
      'checked': checked,
      'inSync': drift.isEmpty,
      'drift': [
        for (final item in drift)
          {'kind': item.kind, 'message': item.message, 'paths': item.paths},
      ],
      'notChecked': [for (final step in plan.legacy) step.id],
    });

    if (plan.legacy.isNotEmpty) {
      output.info(
        'Not checked, since they are not on the engine yet: '
        '${plan.legacy.map((step) => step.id).join(', ')}.',
      );
    }

    if (drift.isEmpty && !checked) {
      // Without processors of the engine there is no lock to be in sync with,
      // since only a run of the engine writes it.
      output.info(
        'Nothing to check: no processor of the engine is selected, and the '
        'others cannot be checked.',
      );

      return ExitCodes.ok;
    }

    if (drift.isEmpty) {
      output.success(
        plan.legacy.isEmpty
            ? 'In sync.'
            : 'In sync, as far as the engine can tell: the processors above '
                  'are not checked.',
      );
      output.summary('Status', countChanges(preview));

      return ExitCodes.ok;
    }

    for (final item in drift) {
      output.info(item.message);
    }
    output.summary('Status', countChanges(preview));
    output.err('The project drifted from flavorizr.yaml or flavorizr.lock.');

    return ExitCodes.attention;
  }
}

/// One way the project drifted: what it is (`lock`, `flavors`, `files`,
/// `edited`), what to tell about it, and the files it concerns.
final class _Drift {
  final String kind;
  final String message;
  final List<String> paths;

  const _Drift(this.kind, this.message, [this.paths = const []]);
}
