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

import 'package:flutter_flavorizr/src/engine/lock/lock_store.dart';
import 'package:flutter_flavorizr/src/entrypoint/adopt_runner.dart';
import 'package:flutter_flavorizr/src/entrypoint/commands/flavorizr_command.dart';
import 'package:flutter_flavorizr/src/entrypoint/exit_codes.dart';
import 'package:flutter_flavorizr/src/entrypoint/plan_report.dart';
import 'package:flutter_flavorizr/src/entrypoint/run_plan.dart';

/// `flavorizr adopt [target...]`: records a project flavorized with 2.x as the
/// baseline of 3.x, and writes nothing but `flavorizr.lock`.
///
/// 2.x left no lock, and it does not mark most of what it wrote. Without one,
/// every file that exists would be a conflict. With the files of the project as
/// the baseline, the next `plan` shows what 3.0 makes of them as an ordinary
/// change, which is reviewed, and applied or not.
class AdoptCommand extends FlavorizrCommand {
  /// Creates the command.
  AdoptCommand(super.context) {
    argParser.addMultiOption(
      'flavors',
      splitCommas: true,
      valueHelp: 'a,b,c',
      help:
          'Flavors the project had and flavorizr.yaml no longer has. 2.x left '
          'no record of them, so they cannot be found: with their names, the '
          'next plan removes their files.',
    );
  }

  @override
  String get name => 'adopt';

  @override
  String get description =>
      'Records a project flavorized with 2.x as the baseline of flavorizr.lock '
      'and writes nothing else: the next plan shows what 3.x would change as '
      'an ordinary diff.';

  @override
  String get invocation => '${runner!.executableName} adopt [target...]';

  @override
  Future<int> execute() async {
    final named = _namedFlavors();
    final config = loadConfig();
    final historical = _historicalFlavors(named, config.flavors.keys);
    final store = LockStore(
      context.projectRoot,
      runningVersion: context.version,
    );

    if (await store.read() != null) {
      throw CommandFailure(
        ExitCodes.data,
        '${LockStore.fileName} exists already: the project has been run by '
        '3.x, and there is nothing to adopt. Delete it to adopt the project '
        'again.',
      );
    }

    final plan = resolveRunPlan(
      registry: context.registry,
      config: config,
      targets: argResults!.rest,
    );

    plan.messages.forEach(output.info);

    if (plan.engine.steps.isEmpty) {
      output.info('Nothing to adopt: no processor of the engine is selected.');

      return ExitCodes.ok;
    }

    output.info(renderRunPlan(plan));

    final verbose = output.verbose;
    final run = await output.busy(
      'Reading the project',
      () => runAdoption(
        context,
        config: config,
        plan: plan,
        named: historical,
        logger: verbose ? output.logger : output.warningsLogger,
        observer: output,
      ),
    );

    if (!run.report.succeeded) return run.report.exitCode;

    final adoption = run.adoption!;
    final recorded = adoption.recorded.values.expand((paths) => paths).length;

    for (final path in [...adoption.userOwned, ...adoption.launchScreens]) {
      output.info('Yours, left alone: $path');
    }

    if (adoption.lock.flavors.isEmpty && config.flavors.isNotEmpty) {
      output.info(
        'The flavors are not recorded in the lock: only an adoption that '
        'covers every processor of the engine records them, and the one of '
        'some targets, or of a default recipe that leaves processors out, '
        'does not.',
      );
    }

    if (plan.legacy.isNotEmpty) {
      output.info(
        'Not adopted, since they are not on the engine yet: '
        '${plan.legacy.map((step) => step.id).join(', ')}.',
      );
    }

    output.success(
      'Adopted $recorded file${recorded == 1 ? '' : 's'} into '
      '${LockStore.fileName}. No other file was written: run `flavorizr plan` '
      'to see what 3.x would change.',
    );

    return ExitCodes.ok;
  }

  /// The names of `--flavors`, trimmed and without the empty ones, each of
  /// which must be a name that can be a folder.
  Set<String> _namedFlavors() {
    final names = (argResults!['flavors'] as List<String>)
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toSet();

    for (final name in names) {
      if (name == '.' || name == '..' || name.contains(RegExp(r'[/\\\x00]'))) {
        throw CommandFailure(
          ExitCodes.usage,
          '`$name` cannot be the name of a flavor: it is not a name of a '
          'folder.',
        );
      }
    }

    return names;
  }

  /// The [named] flavors, which must be historical: ones [configured] does not
  /// have.
  ///
  /// A flavor `flavorizr.yaml` has is not historical, and naming it would take
  /// its files for the ones of a flavor that is gone. Names that differ by case
  /// only are the same folder on a file system that ignores case, so they count
  /// as one name: that of the configuration, or the one given twice.
  Set<String> _historicalFlavors(
    Set<String> named,
    Iterable<String> configured,
  ) {
    final seen = {for (final name in configured) name.toLowerCase(): name};

    for (final name in named) {
      final other = seen[name.toLowerCase()];

      if (other != null) {
        throw CommandFailure(
          ExitCodes.usage,
          configured.contains(other)
              ? '`$name` is a flavor of flavorizr.yaml'
                    '${other == name ? '' : ' (as `$other`, the same folder)'}'
                    ': --flavors is for the flavors it no longer has.'
              : '`$name` and `$other` are the same folder: name it once.',
        );
      }

      seen[name.toLowerCase()] = name;
    }

    return named;
  }
}
