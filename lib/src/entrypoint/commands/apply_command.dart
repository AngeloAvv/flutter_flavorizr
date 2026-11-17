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

import 'package:flutter_flavorizr/src/engine/conflict/conflict_policy.dart';
import 'package:flutter_flavorizr/src/entrypoint/commands/flavorizr_command.dart';
import 'package:flutter_flavorizr/src/entrypoint/engine_runner.dart';
import 'package:flutter_flavorizr/src/entrypoint/exit_codes.dart';
import 'package:flutter_flavorizr/src/entrypoint/plan_report.dart';
import 'package:flutter_flavorizr/src/entrypoint/run_plan.dart';

/// `flavorizr apply [target...]`: shows what would change, asks, and applies it.
///
/// It is the command that runs when no command is given.
class ApplyCommand extends TargetCommand {
  /// Creates the command.
  ApplyCommand(super.context) {
    argParser
      ..addFlag(
        'yes',
        abbr: 'y',
        negatable: false,
        help: 'Does not ask for confirmation, which is what a CI wants.',
      )
      ..addFlag(
        'force',
        abbr: 'f',
        negatable: false,
        hide: true,
        help: 'The 2.x way to say --yes.',
      )
      ..addOption(
        'on-conflict',
        allowed: [for (final policy in ConflictPolicy.values) policy.name],
        allowedHelp: {
          ConflictPolicy.keep.name:
              'leave the files edited by hand as they are',
          ConflictPolicy.overwrite.name: 'replace the files edited by hand',
        },
        help:
            'What to do with the files edited by hand that a run would change. '
            'Without it a terminal asks for each file, and anything else fails.',
      );
  }

  @override
  String get name => 'apply';

  @override
  String get description =>
      'Shows what would change, asks for confirmation and applies it. '
      'It is what runs when no command is given.';

  @override
  String get invocation => '${runner!.executableName} apply [target...]';

  bool get _yes => argResults!['yes'] == true || argResults!['force'] == true;

  @override
  Future<int> execute() async {
    final config = loadConfig();
    final plan = resolve(config);

    logger.info('Flavorization process started');
    logger.info(renderRunPlan(plan));

    if (plan.isEmpty) return ExitCodes.ok;

    // Before anything is written: the engine goes first.
    context.legacy.check(plan.legacy);

    var generated = const <String>{};

    if (plan.engine.steps.isNotEmpty) {
      final run = await runEngine(
        context,
        config: config,
        plan: plan,
        logger: logger,
        approve: (preview) => _approve(preview, plan),
        policy: switch (argResults!['on-conflict']) {
          final String value => ConflictPolicy.tryParse(value),
          _ => null,
        },
        yes: _yes,
      );

      if (!run.report.succeeded) return run.report.exitCode;
      if (run.cancelled) return _cancelled();

      generated = run.generated;
    } else if (!await _confirm()) {
      return _cancelled();
    }

    try {
      await context.legacy.run(
        plan.legacy,
        logger: logger,
        preserve: generated,
      );
    } on Object {
      if (plan.engine.steps.isNotEmpty) {
        logger.warn(
          'The processors of the engine already finished and their changes '
          'are written, with flavorizr.lock. The 2.x processors that follow '
          'did not: run flavorizr again once the problem is fixed.',
        );
      }

      rethrow;
    }

    logger.success('Flavorization process finished');

    return ExitCodes.ok;
  }

  /// Whether to go on, once the changes of the engine are known.
  Future<bool> _approve(EnginePreview preview, RunPlan plan) async {
    logger.info(renderPreview(preview));

    // Nothing to lose: the lock is all that may change.
    if (!preview.hasChanges && plan.legacy.isEmpty) return true;

    return _confirm();
  }

  Future<bool> _confirm() async =>
      _yes || await context.confirm('Do you want to proceed?');

  int _cancelled() {
    logger.info('Flavorization process cancelled');

    return ExitCodes.ok;
  }
}
