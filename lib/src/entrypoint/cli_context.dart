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

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_flavorizr/src/engine/conflict/conflict_terminal.dart';
import 'package:flutter_flavorizr/src/engine/flavorizr_processor.dart';
import 'package:flutter_flavorizr/src/entrypoint/legacy_pipeline.dart';
import 'package:flutter_flavorizr/src/entrypoint/output/output.dart';
import 'package:flutter_flavorizr/src/entrypoint/output/output_environment.dart';
import 'package:flutter_flavorizr/src/entrypoint/processor_registry.dart';
import 'package:flutter_flavorizr/src/utils/version.dart';
import 'package:mason_logger/mason_logger.dart';

/// Asks the user [question] and returns whether the answer was yes.
typedef Confirm = Future<bool> Function(String question);

/// Asks the user [question] and returns the answer, [defaultValue] when there
/// is none.
typedef Prompt =
    Future<String> Function(String question, {required String defaultValue});

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

  final Confirm? _confirm;

  final Prompt? _prompt;

  /// Asks a question that has a default answer. Without a terminal to answer
  /// it, nothing is asked and the default is the answer.
  Prompt get prompt => _prompt ?? _askForText;

  /// Asks for the confirmation of `apply`. Without a terminal to answer it,
  /// nothing is asked and the answer is yes: a CI has nobody to ask.
  Confirm get confirm => _confirm ?? _askIfAnybodyIsThere;

  /// What the process looks like: whether output goes to a terminal, and what
  /// the terminal can show. It decides how the commands print.
  final OutputEnvironment environment;

  /// Where the JSON document and the animation are written: stdout.
  final StringSink sink;

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
    Prompt? prompt,
    ProcessorRegistry? registry,
    LegacyPipeline? legacy,
    FlutterVersionProbe? flutterVersion,
    OutputEnvironment? environment,
    StringSink? sink,
    this.version = flavorizrVersion,
  }) : terminal = terminal ?? const ConsoleConflictTerminal(),
       environment = environment ?? OutputEnvironment.current(),
       sink = sink ?? stdout,
       _confirm = confirm,
       _prompt = prompt,
       registry = registry ?? ProcessorRegistry.standard(),
       legacy = legacy ?? StandardLegacyPipeline(projectRoot),
       flutterVersion = flutterVersion ?? probeFlutterVersion;

  Future<String> _askForText(
    String question, {
    required String defaultValue,
  }) async => environment.interactive
      ? logger.prompt(question, defaultValue: defaultValue)
      : defaultValue;

  Future<bool> _askIfAnybodyIsThere(String question) async =>
      environment.interactive
      ? logger.confirm(question, defaultValue: true)
      : true;

  /// How a command prints: [json] asks for the document of `--json`.
  Output createOutput({bool json = false}) => Output.create(
    logger: logger,
    environment: environment,
    json: json,
    sink: sink,
  );

  /// The context of the real thing: the project is the working directory, and
  /// the [processors] of the project run along with the ones of flavorizr, and
  /// its [overrides] replace the ones that have their ids.
  factory CliContext.standard({
    required Logger logger,
    Iterable<FlavorizrProcessor> processors = const [],
    Iterable<FlavorizrProcessor> overrides = const [],
  }) => CliContext(
    projectRoot: Directory.current,
    logger: logger,
    registry: ProcessorRegistry.standard().withProcessors(
      processors,
      overrides: overrides,
    ),
  );
}

/// Asks [executable], `flutter` of the `PATH` by default, for its version.
///
/// It is `null` when the version cannot be told: flutter is missing, fails, or
/// has not finished after [timeout]. The timeout bounds the whole probe, its
/// output included, since a child of flutter may keep that open after flutter
/// exited. Whatever is still running then is killed, so that it does not
/// outlive the command.
Future<String?> probeFlutterVersion({
  String executable = 'flutter',
  Duration timeout = const Duration(seconds: 60),
}) async {
  Process? process;
  final subscriptions = <StreamSubscription<List<int>>>[];

  // The bytes of [stream], which are decoded last so that a stray one cannot
  // fail the stream. The future is awaited from the start, by `Future.wait`.
  Future<List<int>> read(Stream<List<int>> stream) {
    final done = Completer<List<int>>();
    final bytes = <int>[];

    subscriptions.add(
      stream.listen(
        bytes.addAll,
        onDone: () => done.complete(bytes),
        onError: done.completeError,
        cancelOnError: true,
      ),
    );

    return done.future;
  }

  try {
    process = await Process.start(executable, [
      '--version',
      '--machine',
    ], runInShell: Platform.isWindows);

    final [exitCode as int, stdout as List<int>, _] = await Future.wait<Object>(
      [process.exitCode, read(process.stdout), read(process.stderr)],
    ).timeout(timeout);

    if (exitCode != 0) return null;

    // Flutter may print noise before the JSON document.
    final output = utf8.decode(stdout, allowMalformed: true);
    final match = RegExp(r'"frameworkVersion"\s*:\s*"([^"]+)"').firstMatch(
      output.substring(output.contains('{') ? output.indexOf('{') : 0),
    );

    return match?.group(1);
  } on Object {
    return null;
  } finally {
    process?.kill(ProcessSignal.sigkill);

    for (final subscription in subscriptions) {
      unawaited(subscription.cancel());
    }
  }
}
