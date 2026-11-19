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

import 'package:args/command_runner.dart';
import 'package:flutter_flavorizr/src/engine/execution_plan.dart';
import 'package:flutter_flavorizr/src/engine/lock/lock_store.dart';
import 'package:flutter_flavorizr/src/engine/reconcile/destructive_removal.dart';
import 'package:flutter_flavorizr/src/entrypoint/cli_context.dart';
import 'package:flutter_flavorizr/src/entrypoint/deprecated_options.dart';
import 'package:flutter_flavorizr/src/entrypoint/engine_runner.dart';
import 'package:flutter_flavorizr/src/exception/configuration_not_found_exception.dart';
import 'package:flutter_flavorizr/src/exception/missing_required_fields_exception.dart';
import 'package:flutter_flavorizr/src/entrypoint/exit_codes.dart';
import 'package:flutter_flavorizr/src/entrypoint/output/documents.dart';
import 'package:flutter_flavorizr/src/entrypoint/output/output.dart';
import 'package:flutter_flavorizr/src/entrypoint/run_plan.dart';
import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:flutter_flavorizr/src/parser/parser.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

/// The exit codes, which every command documents in its help.
const exitCodesHelp = '''
Exit codes:
  0   everything went well
  1   needs attention: conflicts with files edited by hand, drift (status), or a failed check (doctor)
  64  the command line is wrong
  65  the configuration or the lock cannot be used, or it removes the last flavor or a whole platform
  70  a processor failed, or the project changed during the run''';

/// A command failed in a way that has an exit code, and something to tell.
class CommandFailure implements Exception {
  /// The exit code of the command.
  final int exitCode;

  /// What went wrong.
  final String message;

  /// What was thrown, when the failure reports it.
  final Object? cause;

  /// Creates a failure.
  const CommandFailure(this.exitCode, this.message, {this.cause});
}

/// What the commands have in common: the context, `--verbose`, the help that
/// goes through the logger, the output and the way every error becomes an exit
/// code.
abstract class FlavorizrCommand extends Command<int> {
  /// What the command runs on.
  final CliContext context;

  /// Adds the options every command has.
  FlavorizrCommand(this.context) {
    argParser.addFlag(
      'verbose',
      abbr: 'v',
      negatable: false,
      help: 'Prints what every processor does.',
    );
  }

  /// Adds `--json`, for the commands that have a document to print.
  void addJsonFlag() => argParser.addFlag(
    'json',
    negatable: false,
    help:
        'Prints one JSON document on stdout instead of text, for CI, IDEs and '
        'agents. Warnings and errors still go to stderr. See '
        'https://docs.page/AngeloAvv/flutter_flavorizr/reference/json-output.',
  );

  bool get _json =>
      argParser.options.containsKey('json') && argResults!['json'] == true;

  /// Where the command prints: it decides what that looks like, on a terminal,
  /// in a log, or as the document of `--json`.
  late final Output output = context.createOutput(json: _json);

  @override
  String? get usageFooter => exitCodesHelp;

  // The help is not output of a run: it goes straight to the logger.
  @override
  void printUsage() => context.logger.info(usage);

  /// Runs the command and returns its exit code.
  Future<int> execute();

  /// What to warn about the 2.x options of the command line, which are still
  /// accepted: none by default.
  List<String> get deprecations => const [];

  @override
  Future<int> run() => overrideAnsiOutput(output.style.color, _run);

  Future<int> _run() async {
    if (argResults!['verbose'] == true) output.verbose = true;

    int code;

    try {
      deprecations.forEach(output.warn);

      code = await execute();
    } on CommandFailure catch (failure) {
      output.err(failure.message);

      code = failure.exitCode;
    } on Object catch (error, stackTrace) {
      output.err('$error');
      output.logger.detail('$stackTrace');

      code = ExitCodes.of(error) ?? ExitCodes.software;
    }

    output.finish(name, code);

    return code;
  }

  /// The configuration of the project, or `null` when it has none: no
  /// `flavorizr.yaml` and no `flavorizr` section in `pubspec.yaml`.
  ///
  /// A configuration that exists and cannot be used is not absent: it fails
  /// like [loadConfig] does.
  FlavorizrConfig? loadConfigIfPresent() {
    try {
      return loadConfig();
    } on CommandFailure catch (failure) {
      final cause = failure.cause;
      final noSection =
          cause is MissingRequiredFieldsException &&
          cause.fields.length == 1 &&
          cause.fields.single == 'flavorizr';

      if (cause is ConfigurationNotFoundException || noSection) return null;

      rethrow;
    }
  }

  /// The configuration of the project, from `flavorizr.yaml` or from the
  /// `flavorizr` section of `pubspec.yaml`.
  ///
  /// Fails with the exit code of a configuration that cannot be used.
  FlavorizrConfig loadConfig() {
    final parser = Parser(
      pubspecPath: p.join(context.projectRoot.path, 'pubspec'),
      flavorizrPath: p.join(context.projectRoot.path, 'flavorizr'),
    );

    try {
      final config = parser.parse();

      config.deprecations.forEach(output.warn);

      return config;
    } on Object catch (error) {
      final noConfiguration =
          error is ConfigurationNotFoundException ||
          (error is MissingRequiredFieldsException &&
              error.fields.length == 1 &&
              error.fields.single == 'flavorizr');

      throw CommandFailure(
        ExitCodes.data,
        noConfiguration
            ? '$error\nRun `flavorizr init` to write a flavorizr.yaml.'
            : '$error',
        cause: error,
      );
    }
  }
}

/// A command that runs the processors named by its targets.
abstract class TargetCommand extends FlavorizrCommand {
  /// Adds `[target...]`, and the 2.x `-p`, which still names targets.
  TargetCommand(super.context) {
    addJsonFlag();
    argParser.addMultiOption(
      'processors',
      abbr: 'p',
      splitCommas: true,
      hide: true,
      help: 'The 2.x way to name the targets.',
    );
  }

  late final _processors = DeprecatedProcessors.parse(
    argResults!['processors'] as List<String>,
    commandName: name,
    positional: argResults!.rest,
  );

  @override
  List<String> get deprecations => _processors.warnings;

  /// The recipes and processors to run: the arguments, and the value of `-p`.
  /// None means the default recipe.
  List<String> get targets => [...argResults!.rest, ..._processors.targets];

  /// What to run for [targets] in [config].
  RunPlan resolve(FlavorizrConfig config) {
    // `-p` with ids that are gone only: nothing, and not the default recipe.
    final plan = targets.isEmpty && _processors.leavesNothing
        ? RunPlan(
            messages: const [],
            engine: const ExecutionPlan([]),
            legacy: const [],
            paths: const {},
          )
        : resolveRunPlan(
            registry: context.registry,
            config: config,
            targets: targets,
          );

    for (final message in plan.messages) {
      output.info(message);
    }

    output.data(processorFields(plan));

    return plan;
  }

  /// Fails when [config] asks to remove what flavorizr cannot undo: the last
  /// flavor, or the flavors of a platform that the lock says was flavorized.
  ///
  /// It is meant to run before anything is done, whatever the targets: it
  /// compares the configuration with the lock, and nothing is written. See
  /// [checkRemoval].
  Future<void> checkNothingIsDropped(FlavorizrConfig config) async => checkRemoval(
    previous: await LockStore(
      context.projectRoot,
      runningVersion: context.version,
    ).read(),
    flavors: config.flavors.keys.toSet(),
    platforms: {
      if (config.androidFlavorsAvailable) 'android',
      if (config.iosFlavorsAvailable) 'ios',
      if (config.macosFlavorsAvailable) 'macos',
      if (config.linuxFlavorsAvailable) 'linux',
      if (config.windowsFlavorsAvailable) 'windows',
    },
  );

  /// What the processors of the engine would change, or `null` when there are
  /// none. Fails when one of them does.
  Future<EnginePreview?> dryRun(
    RunPlan plan,
    FlavorizrConfig config, {
    bool overwriteScaffold = false,
  }) async {
    if (plan.engine.steps.isEmpty) return null;

    final verbose = output.verbose;
    final run = await output.busy(
      'Working out the changes',
      () => runEngine(
        context,
        config: config,
        plan: plan,
        logger: verbose ? output.logger : output.warningsLogger,
        overwriteScaffold: overwriteScaffold,
      ),
    );

    if (!run.report.succeeded) {
      throw CommandFailure(
        run.report.exitCode,
        verbose ? 'The plan could not be made.' : run.report.render(),
      );
    }

    return run.preview;
  }
}
