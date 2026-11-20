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

import 'package:flutter_flavorizr/src/entrypoint/commands/flavorizr_command.dart';
import 'package:flutter_flavorizr/src/entrypoint/exit_codes.dart';
import 'package:flutter_flavorizr/src/entrypoint/output/documents.dart';
import 'package:flutter_flavorizr/src/entrypoint/plan_report.dart';

/// `flavorizr plan [target...]`: what `apply` would do, without writing
/// anything.
///
/// The processors run on a shadow workspace, a copy of the files they work on,
/// so the project and its lock are never touched.
class PlanCommand extends TargetCommand {
  /// Creates the command.
  PlanCommand(super.context) {
    argParser.addFlag(
      'overwrite-scaffold',
      negatable: false,
      help:
          'Shows what apply --overwrite-scaffold would do to the scaffold '
          'files that exist.',
    );
  }

  @override
  String get name => 'plan';

  @override
  String get description =>
      'Shows what apply would do: the processors that would run, with the ones '
      'they need marked (auto), and the files that would be added (+), '
      'changed (~) or deleted (-), by platform. Nothing is written.';

  @override
  String get invocation => '${runner!.executableName} plan [target...]';

  @override
  Future<int> execute() async {
    final config = loadConfig();
    final plan = resolve(config);

    await checkNothingIsDropped(config);

    output.info(renderRunPlan(plan));

    final preview = await dryRun(
      plan,
      config,
      overwriteScaffold: argResults!['overwrite-scaffold'] == true,
    );

    output.data(previewFields(preview));

    if (preview == null) return ExitCodes.ok;

    if (preview.adopted case final adopted?) {
      output.info(renderAdoptionNotice(adopted, writes: false));
    }

    output.info(renderPreview(preview, style: output.style));
    output.summary('Plan', countChanges(preview));

    return preview.hasConflicts ? ExitCodes.attention : ExitCodes.ok;
  }
}
