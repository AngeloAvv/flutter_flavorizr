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

import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:flutter_flavorizr/src/engine/flavorizr_processor.dart';
import 'package:flutter_flavorizr/src/entrypoint/cli_context.dart';
import 'package:flutter_flavorizr/src/entrypoint/commands/apply_command.dart';
import 'package:flutter_flavorizr/src/entrypoint/commands/doctor_command.dart';
import 'package:flutter_flavorizr/src/entrypoint/commands/flavorizr_command.dart';
import 'package:flutter_flavorizr/src/entrypoint/commands/list_command.dart';
import 'package:flutter_flavorizr/src/entrypoint/commands/plan_command.dart';
import 'package:flutter_flavorizr/src/entrypoint/commands/status_command.dart';
import 'package:flutter_flavorizr/src/entrypoint/exit_codes.dart';
import 'package:mason_logger/mason_logger.dart';

/// A common entry point to parse command line arguments and execute the
/// command.
///
/// Ends the process with the exit code of the command when it is not `0`: see
/// [ExitCodes]. With no command, `apply` runs.
///
/// The [processors] are the ones of the project, added to the ones of
/// flavorizr.
Future<void> execute(
  List<String> args, {
  Iterable<FlavorizrProcessor> processors = const [],
}) async {
  final logger = Logger();
  final int code;

  try {
    code = await run(
      args,
      context: CliContext.standard(logger: logger, processors: processors),
    );
  } on Object catch (error) {
    // The processors of the project are checked before any command runs.
    final code = ExitCodes.of(error);
    if (code == null) rethrow;

    logger.err('$error');
    exit(code);
  }

  if (code != ExitCodes.ok) exit(code);
}

/// Runs the command named by [args] in [context], and returns its exit code.
///
/// The command may be anywhere in [args], and `apply` runs when there is none.
///
/// A command line that is wrong is reported on stderr, with the usage on
/// stdout. With `--json` stdout is a document and nothing else, so the usage is
/// left out: the command line is not understood, and there is no document.
Future<int> run(List<String> args, {required CliContext context}) {
  final json = args.contains('--json');

  return overrideAnsiOutput(
    context.environment.color && !json,
    () => _run(args, context: context, json: json),
  );
}

Future<int> _run(
  List<String> args, {
  required CliContext context,
  required bool json,
}) async {
  final runner = _Runner(context);

  try {
    return await runner.run(_withCommand(args, runner.commands.keys)) ??
        ExitCodes.ok;
  } on UsageException catch (error) {
    context.logger.err(error.message);
    if (!json) context.logger.info('\n${error.usage}');

    return ExitCodes.usage;
  } on ArgParserException catch (error) {
    context.logger.err(error.message);

    return ExitCodes.usage;
  }
}

/// The options that take a value, wherever they are used.
const _optionsWithValue = {'-p', '--processors', '--on-conflict'};

/// [args] with the command first, which is where the runner wants it, and
/// `apply` when none was given. `--help` alone is the help of the tool.
List<String> _withCommand(List<String> args, Iterable<String> commands) {
  var index = -1;

  for (var i = 0; i < args.length && index == -1; i++) {
    // What follows an option that takes a value is its value, not a command.
    final isValue = i > 0 && _optionsWithValue.contains(args[i - 1]);

    if (!isValue && commands.contains(args[i])) index = i;
  }

  if (index > 0) {
    return [args[index], ...args.take(index), ...args.skip(index + 1)];
  }

  final asksForHelp = args.contains('--help') || args.contains('-h');

  return index == -1 && !asksForHelp ? ['apply', ...args] : args;
}

class _Runner extends CommandRunner<int> {
  final CliContext _context;

  _Runner(this._context)
    : super(
        'flutter_flavorizr',
        'Creates the flavors of a Flutter app: Android, iOS, macOS, Linux and '
            'Windows.\nWith no command, apply runs.',
      ) {
    <FlavorizrCommand>[
      ApplyCommand(_context),
      PlanCommand(_context),
      StatusCommand(_context),
      ListCommand(_context),
      DoctorCommand(_context),
    ].forEach(addCommand);
  }

  @override
  String? get usageFooter => exitCodesHelp;

  @override
  void printUsage() => _context.logger.info(usage);
}
