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

import 'package:path/path.dart' as p;

/// Where a project keeps its own entry point, relative to its root.
const customEntrypointPath = 'tool/flavorizr.dart';

/// The environment variable the delegation sets on the entry point it runs, so
/// that this one does not delegate again.
const delegationGuard = 'FLAVORIZR_DELEGATED';

/// Starts [executable] with [arguments] in [workingDirectory], with
/// [environment] added to the one of the process, hands it the terminal and
/// returns its exit code.
typedef EntrypointStarter =
    Future<int> Function(
      String executable,
      List<String> arguments, {
      required String workingDirectory,
      required Map<String, String> environment,
    });

/// Runs `dart run tool/flavorizr.dart [args]` of the project at [projectRoot]
/// when it has that file, and returns its exit code. Returns `null` when
/// nothing was delegated: the project has no entry point of its own, or this
/// run is the delegated one.
///
/// The project keeps a single command, `dart run flutter_flavorizr`, whether it
/// registers processors of its own or not. The entry point that is run is
/// started with [delegationGuard] set, which is what stops it from delegating
/// to itself, or to a copy of itself, forever.
Future<int?> delegateToCustomEntrypoint(
  List<String> args, {
  Directory? projectRoot,
  Map<String, String>? environment,
  EntrypointStarter start = _start,
  String? dart,
}) async {
  final env = environment ?? Platform.environment;
  if (env.containsKey(delegationGuard)) return null;

  final root = projectRoot ?? Directory.current;
  if (!File(p.join(root.path, customEntrypointPath)).existsSync()) return null;

  return start(
    dart ?? Platform.resolvedExecutable,
    ['run', customEntrypointPath, ...args],
    workingDirectory: root.path,
    environment: {delegationGuard: '1'},
  );
}

Future<int> _start(
  String executable,
  List<String> arguments, {
  required String workingDirectory,
  required Map<String, String> environment,
}) async {
  final process = await Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    environment: environment,
    mode: ProcessStartMode.inheritStdio,
  );

  return process.exitCode;
}
