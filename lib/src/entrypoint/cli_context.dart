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

import 'dart:convert';
import 'dart:io';

import 'package:flutter_flavorizr/src/engine/conflict/conflict_terminal.dart';
import 'package:flutter_flavorizr/src/entrypoint/legacy_pipeline.dart';
import 'package:flutter_flavorizr/src/entrypoint/processor_registry.dart';
import 'package:flutter_flavorizr/src/utils/version.dart';
import 'package:mason_logger/mason_logger.dart';

/// Asks the user [question] and returns whether the answer was yes.
typedef Confirm = Future<bool> Function(String question);

/// The version of the Flutter SDK that is installed, or `null` when it cannot
/// be told.
typedef FlutterVersionProbe = Future<String?> Function();

/// Everything the commands depend on, so that a test can replace it: the
/// project, where to print and ask, which processors exist and how the ones
/// that are not on the engine run.
class CliContext {
  /// The root of the project: the directory that holds `pubspec.yaml`.
  final Directory projectRoot;

  /// Where the commands print.
  final Logger logger;

  /// Where conflicts are asked about.
  final ConflictTerminal terminal;

  /// Asks for the confirmation of `apply`.
  final Confirm confirm;

  /// Every processor, on the engine or not.
  final ProcessorRegistry registry;

  /// Runs the processors that are not on the engine.
  final LegacyPipeline legacy;

  /// Tells the version of Flutter, for `doctor`.
  final FlutterVersionProbe flutterVersion;

  /// The version of flavorizr, which the lock records.
  final String version;

  /// Creates a context.
  CliContext({
    required this.projectRoot,
    required this.logger,
    ConflictTerminal? terminal,
    Confirm? confirm,
    ProcessorRegistry? registry,
    LegacyPipeline? legacy,
    FlutterVersionProbe? flutterVersion,
    this.version = flavorizrVersion,
  }) : terminal = terminal ?? const ConsoleConflictTerminal(),
       confirm =
           confirm ??
           ((question) async => logger.confirm(question, defaultValue: true)),
       registry = registry ?? ProcessorRegistry.standard(),
       legacy = legacy ?? StandardLegacyPipeline(projectRoot),
       flutterVersion = flutterVersion ?? probeFlutterVersion;

  /// The context of the real thing: the project is the working directory.
  factory CliContext.standard({required Logger logger}) =>
      CliContext(projectRoot: Directory.current, logger: logger);
}

/// Asks [executable], `flutter` of the `PATH` by default, for its version.
///
/// It is `null` when the version cannot be told: flutter is missing, fails, or
/// has not answered after [timeout], in which case it is killed so that it does
/// not outlive the command.
Future<String?> probeFlutterVersion({
  String executable = 'flutter',
  Duration timeout = const Duration(seconds: 60),
}) async {
  Process? process;

  try {
    process = await Process.start(executable, [
      '--version',
      '--machine',
    ], runInShell: Platform.isWindows);

    // Both streams are read to the end, or a chatty flutter would block on a
    // full pipe, and a killed one would leave them open.
    final stdout = process.stdout.transform(utf8.decoder).join();
    final stderr = process.stderr.drain<void>();
    final exitCode = await process.exitCode.timeout(timeout);

    await stderr;

    if (exitCode != 0) return null;

    // Flutter may print noise before the JSON document.
    final output = await stdout;
    final match = RegExp(r'"frameworkVersion"\s*:\s*"([^"]+)"').firstMatch(
      output.substring(output.contains('{') ? output.indexOf('{') : 0),
    );

    return match?.group(1);
  } on Object {
    process?.kill(ProcessSignal.sigkill);

    return null;
  }
}
