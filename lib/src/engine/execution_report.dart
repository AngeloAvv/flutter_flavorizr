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

import 'package:io/io.dart';

/// What happened to the processors of an `ExecutionPlan` when it was applied.
///
/// Every processor of the plan is in exactly one of [completed], [failed] and
/// [skipped].
final class ExecutionReport {
  /// The ids of the processors that were applied, in execution order.
  final List<String> completed;

  /// The id of the processor that threw, or `null` when no processor did.
  ///
  /// The run can fail without it: a resource that fails to set up or to tear
  /// down is not a processor. See [error].
  final String? failed;

  /// The ids of the processors that were never applied, because an earlier
  /// failure aborted the run.
  final List<String> skipped;

  /// What aborted the run, or `null` when it went well.
  final Object? error;

  /// Where [error] was thrown.
  final StackTrace? stackTrace;

  /// Creates a report.
  ExecutionReport({
    required Iterable<String> completed,
    required Iterable<String> skipped,
    this.failed,
    this.error,
    this.stackTrace,
  }) : completed = List.unmodifiable(completed),
       skipped = List.unmodifiable(skipped);

  /// Whether every processor was applied and nothing failed.
  bool get succeeded => error == null;

  /// The exit code the process must end with: `0` when the run [succeeded].
  int get exitCode => succeeded ? 0 : ExitCode.software.code;

  /// A human readable summary of the run, one line per outcome.
  String render() {
    final lines = <String>[
      if (completed.isNotEmpty) 'Completed: ${completed.join(', ')}',
      if (failed != null) 'Failed: $failed ($error)',
      if (failed == null && error != null) 'Failed: $error',
      if (skipped.isNotEmpty) 'Skipped: ${skipped.join(', ')}',
    ];

    return lines.join('\n');
  }
}
