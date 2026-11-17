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

/// The variables that tell the process runs in a CI, besides `CI` itself.
const _ciVariables = [
  'GITHUB_ACTIONS',
  'GITLAB_CI',
  'BUILDKITE',
  'CIRCLECI',
  'JENKINS_URL',
  'TF_BUILD',
  'TEAMCITY_VERSION',
  'TRAVIS',
  'APPVEYOR',
];

/// What the process looks like to the output: whether a person is looking at
/// it, and what their terminal can show.
///
/// It is the one place that decides between a rich output (spinners, colours)
/// and a linear one (plain lines for a log), so that every command decides the
/// same way and a test can pick either.
final class OutputEnvironment {
  /// Whether stdout is a terminal, and not a pipe or a file.
  final bool stdoutIsTerminal;

  /// Whether stderr is a terminal. Warnings and errors go there.
  final bool stderrIsTerminal;

  /// Whether stdin is a terminal, which is to say that somebody may answer.
  final bool stdinIsTerminal;

  /// Whether the terminal understands ANSI escape sequences. It is a console
  /// that enabled them on Windows, where older ones do not.
  final bool supportsAnsi;

  /// The environment variables the output reads: `CI`, `NO_COLOR`, `TERM`.
  final Map<String, String> variables;

  /// Creates an environment.
  const OutputEnvironment({
    required this.stdoutIsTerminal,
    required this.stderrIsTerminal,
    required this.stdinIsTerminal,
    required this.supportsAnsi,
    this.variables = const {},
  });

  /// A process whose streams are all piped or redirected, which is what a CI
  /// or a script sees: linear output, no colour, nobody to ask.
  const OutputEnvironment.plain()
    : stdoutIsTerminal = false,
      stderrIsTerminal = false,
      stdinIsTerminal = false,
      supportsAnsi = false,
      variables = const {};

  /// The environment of this process.
  factory OutputEnvironment.current() {
    bool probe(bool Function() read) {
      try {
        return read();
      } on Object {
        // A stream that was closed has no terminal.
        return false;
      }
    }

    return OutputEnvironment(
      stdoutIsTerminal: probe(() => stdout.hasTerminal),
      stderrIsTerminal: probe(() => stderr.hasTerminal),
      stdinIsTerminal: probe(() => stdin.hasTerminal),
      supportsAnsi: probe(
        () => stdout.supportsAnsiEscapes && stderr.supportsAnsiEscapes,
      ),
      variables: Platform.environment,
    );
  }

  /// Whether `NO_COLOR` is set to a value (https://no-color.org): it is
  /// present and not empty.
  bool get noColor => (variables['NO_COLOR'] ?? '').isNotEmpty;

  /// Whether the process runs in a CI: `CI` is set to something that is not
  /// false, or the variable of a known CI is.
  bool get ci {
    final value = (variables['CI'] ?? '').toLowerCase();

    return (value.isNotEmpty && value != 'false' && value != '0') ||
        _ciVariables.any((name) => (variables[name] ?? '').isNotEmpty);
  }

  /// Whether the output may redraw a line: spinners.
  ///
  /// It takes a terminal that understands ANSI escapes on both stdout and
  /// stderr, which is not `dumb` and is not a CI: a CI keeps its logs, and a
  /// redrawn line there is a hundred lines of noise.
  bool get animated =>
      stdoutIsTerminal &&
      stderrIsTerminal &&
      supportsAnsi &&
      variables['TERM'] != 'dumb' &&
      !ci;

  /// Whether the output may carry colour: whenever it animates, unless the
  /// user asked for none with `NO_COLOR`.
  bool get color => animated && !noColor;

  /// Whether somebody may be asked a question: input and output are a
  /// terminal. A CI that hands out a pseudo terminal can still be answered,
  /// which is a choice of whoever runs it.
  bool get interactive => stdinIsTerminal && stdoutIsTerminal;
}
