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
import 'dart:io' as io;

import 'package:flutter_flavorizr/src/engine/conflict/conflict_terminal.dart';
import 'package:flutter_flavorizr/src/engine/step_observer.dart';
import 'package:flutter_flavorizr/src/entrypoint/output/output_environment.dart';
import 'package:flutter_flavorizr/src/entrypoint/output/style.dart';
import 'package:mason_logger/mason_logger.dart';

/// The version of the document `--json` prints. It changes only when a field is
/// removed, renamed or changes type, which is not before 4.0.
const jsonSchemaVersion = 1;

/// How a command prints.
enum OutputMode {
  /// Linear lines, with no colour and no animation: what a log, a pipe or a CI
  /// wants.
  plain,

  /// A terminal: colour, a spinner for each step and a summary.
  rich,

  /// One JSON document on stdout, for machines.
  json,
}

/// How the files of a run changed: the summary of `plan`, `apply` and `status`.
final class ChangeCounts {
  /// The files that are added.
  final int added;

  /// The files that are changed.
  final int modified;

  /// The files that are deleted.
  final int deleted;

  /// The changes that would lose something edited by hand.
  final int conflicts;

  /// Creates the counts.
  const ChangeCounts({
    this.added = 0,
    this.modified = 0,
    this.deleted = 0,
    this.conflicts = 0,
  });

  /// `+N ~M -K`.
  String get symbols => '+$added ~$modified -$deleted';

  /// The counts as the `summary` of a JSON document.
  Map<String, int> toJson() => {
    'added': added,
    'modified': modified,
    'deleted': deleted,
    'conflicts': conflicts,
  };
}

/// How a processor ended, for the record of a run.
enum StepStatus {
  /// It ran to the end.
  completed,

  /// It threw, which aborted the run.
  failed,
}

/// A processor that ran, and for how long.
final class StepRecord {
  /// The id of the processor.
  final String id;

  /// How it ended.
  final StepStatus status;

  /// How long it took.
  final Duration elapsed;

  /// Creates a record.
  const StepRecord(this.id, this.status, this.elapsed);
}

/// Where a command prints, and the only way it does.
///
/// A command says *what* happened (a line of text, a step that ran, a summary,
/// the fields of its document) and the output decides *how* it looks: rich on a
/// terminal, linear everywhere else, a JSON document with `--json`. So no
/// command prints on its own, and the rule that decides between the three is
/// in one place: [Output.create].
///
/// Whatever the mode, warnings and errors go to stderr, and stdout is for the
/// result. With `--json`, stdout holds nothing but the document.
abstract class Output implements StepObserver {
  /// Picks the output for [environment]: [json] asks for the document, a
  /// terminal gets the rich one, and anything else the plain one.
  ///
  /// [logger] is where text goes, [sink] where the document and the animation
  /// are written (stdout by default).
  factory Output.create({
    required Logger logger,
    required OutputEnvironment environment,
    bool json = false,
    StringSink? sink,
    Duration frameInterval = const Duration(milliseconds: 80),
  }) {
    final out = sink ?? io.stdout;

    if (json) return _JsonOutput(logger, environment, out);
    if (environment.animated) {
      return _RichOutput(logger, environment, out, frameInterval);
    }

    return _PlainOutput(logger, environment, out);
  }

  /// What the process looks like.
  final OutputEnvironment environment;

  /// The logger text goes through.
  final Logger _base;

  /// Where the document and the animation are written.
  final StringSink _out;

  final Stopwatch _clock = Stopwatch()..start();
  final List<StepRecord> _steps = [];
  final List<String> _warnings = [];
  final List<String> _errors = [];

  Output._(this._base, this.environment, this._out);

  /// How this output prints.
  OutputMode get mode;

  /// Whether the output is the JSON document.
  bool get isJson => mode == OutputMode.json;

  /// How colour is applied: not at all, but in the rich output, unless
  /// `NO_COLOR` is set.
  Style get style => const Style.none();

  /// The logger of a dry run: warnings and errors, which are told, and nothing
  /// else, since a dry run has no processor to announce.
  Logger get warningsLogger => _OutputLogger(this, warningsOnly: true);

  /// The logger of what the output does not print itself: the processors and
  /// the engine. It follows the rules of the mode.
  Logger get logger;

  /// How long ago the command started.
  Duration get elapsed => _clock.elapsed;

  /// What the processors that ran did, in order.
  List<StepRecord> get steps => List.unmodifiable(_steps);

  /// The warnings so far.
  List<String> get warnings => List.unmodifiable(_warnings);

  /// The errors so far.
  List<String> get errors => List.unmodifiable(_errors);

  /// Whether the processors print what they do.
  bool get verbose => _base.level == Level.verbose;

  set verbose(bool value) {
    if (value) _base.level = Level.verbose;
  }

  /// A line of text for the person at the terminal: not in `--json`.
  void info(String message);

  /// A line that says something went well: not in `--json`.
  void success(String message);

  /// A warning, on stderr. It is part of the document with `--json`.
  void warn(String message) {
    _warnings.add(message);
    _base.warn(message);
  }

  /// An error, on stderr. It is part of the document with `--json`.
  void err(String message) {
    _errors.add(message);
    _base.err(message);
  }

  /// The terminal conflicts are asked about: [base], unless nobody can be asked.
  ConflictTerminal terminal(ConflictTerminal base) => base;

  /// Runs [body] while [label] is shown as work in progress, and takes it away
  /// when it is done. Only the rich output shows anything.
  Future<T> busy<T>(String label, Future<T> Function() body) => body();

  @override
  void started(String id);

  @override
  void finished(String id, Duration elapsed) {
    _steps.add(StepRecord(id, StepStatus.completed, elapsed));
  }

  @override
  void failed(String id, Duration elapsed, Object error) {
    _steps.add(StepRecord(id, StepStatus.failed, elapsed));
  }

  /// The end of a run of [verb] (`Plan`, `Applied`, `Status`): the counts of its
  /// changes and how long it took. Not in `--json`, where `summary` is a field.
  void summary(String verb, ChangeCounts counts);

  /// Adds [fields] to the document. Only `--json` has one.
  void data(Map<String, Object?> fields) {}

  /// The command [command] is over with [exitCode]. It prints the document with
  /// `--json`, and takes away what is still being drawn otherwise.
  void finish(String command, int exitCode) {}
}

/// Prints [duration] the way a person reads it: `12 ms`, `1.2 s`, `1 m 5 s`.
String formatDuration(Duration duration) {
  final ms = duration.inMilliseconds;

  if (ms < 1000) return '$ms ms';
  if (ms < 60000) return '${(ms / 1000).toStringAsFixed(1)} s';

  return '${duration.inMinutes} m ${duration.inSeconds % 60} s';
}

/// The platform of a processor, which is how steps are grouped: `android` for
/// `android:icons`.
String platformOfProcessor(String id) =>
    id.contains(':') ? id.substring(0, id.indexOf(':')) : id;

/// Linear text: no colour, no animation. What a log, a pipe and a CI get.
class _PlainOutput extends Output {
  String? _platform;

  _PlainOutput(super._base, super.environment, super._out) : super._();

  @override
  OutputMode get mode => OutputMode.plain;

  @override
  Logger get logger => _base;

  @override
  void info(String message) => _base.info(message);

  @override
  void success(String message) => _base.success(message);

  /// Names the platform of [id] when it is not the one of the step before.
  void _group(String id) {
    final platform = platformOfProcessor(id);

    if (platform == _platform) return;

    _platform = platform;
    _base.info(style.bold(platform));
  }

  @override
  void started(String id) {}

  @override
  void finished(String id, Duration elapsed) {
    super.finished(id, elapsed);
    _group(id);
    _base.info('  ${style.green('ok')} $id (${formatDuration(elapsed)})');
  }

  @override
  void failed(String id, Duration elapsed, Object error) {
    super.failed(id, elapsed, error);
    _group(id);
    _base.info('  ${style.red('failed')} $id (${formatDuration(elapsed)})');
  }

  @override
  void summary(String verb, ChangeCounts counts) {
    final conflicts = counts.conflicts;

    _base.info(
      '$verb: ${counts.symbols}, '
      '$conflicts ${conflicts == 1 ? 'conflict' : 'conflicts'} '
      '(${formatDuration(elapsed)})',
    );
  }
}

const _frames = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'];

/// A terminal: colour (unless `NO_COLOR`), a spinner for each step, a summary.
class _RichOutput extends _PlainOutput {
  final Duration _frameInterval;
  late final Logger _logger = _OutputLogger(this);
  Timer? _timer;
  var _frame = 0;
  var _label = '';

  _RichOutput(super._base, super.environment, super._out, this._frameInterval);

  @override
  OutputMode get mode => OutputMode.rich;

  @override
  Style get style => Style(color: environment.color);

  @override
  Logger get logger => _logger;

  /// Whether a spinner can be drawn: it cannot while the processors print, since
  /// their lines would end up in the middle of it.
  bool get _spins => !verbose;

  void _draw() => _out.write(
    '\r\x1B[2K  ${style.cyan(_frames[_frame % _frames.length])} $_label',
  );

  void _spin(String label) {
    _stop();
    _label = label;
    _frame = 0;
    _draw();
    _timer = Timer.periodic(_frameInterval, (_) {
      _frame++;
      _draw();
    });
  }

  /// Takes the spinner away, if there is one, and leaves the line blank.
  void _stop() {
    if (_timer == null) return;

    _timer!.cancel();
    _timer = null;
    _out.write('\r\x1B[2K');
  }

  @override
  Future<T> busy<T>(String label, Future<T> Function() body) async {
    if (!_spins) return body();

    _spin(label);

    try {
      return await body();
    } finally {
      _stop();
    }
  }

  @override
  void started(String id) {
    _group(id);

    if (_spins) _spin(id);
  }

  @override
  void finished(String id, Duration elapsed) {
    _stop();
    _steps.add(StepRecord(id, StepStatus.completed, elapsed));
    _base.info(
      '  ${style.green('✓')} $id ${style.dim(formatDuration(elapsed))}',
    );
  }

  @override
  void failed(String id, Duration elapsed, Object error) {
    _stop();
    _steps.add(StepRecord(id, StepStatus.failed, elapsed));
    _base.info('  ${style.red('✗')} $id ${style.dim(formatDuration(elapsed))}');
  }

  @override
  void success(String message) => super.success('${style.green('✓')} $message');

  @override
  void summary(String verb, ChangeCounts counts) {
    final conflicts = counts.conflicts;

    _base.info(
      '${style.bold(verb)}  '
      '${style.green('+${counts.added}')} '
      '${style.yellow('~${counts.modified}')} '
      '${style.red('-${counts.deleted}')}'
      '${conflicts == 0 ? '' : '  ${style.red('$conflicts ${conflicts == 1 ? 'conflict' : 'conflicts'}')}'}'
      '  ${style.dim('in ${formatDuration(elapsed)}')}',
    );
  }

  @override
  void finish(String command, int exitCode) => _stop();
}

/// One JSON document on stdout, and nothing else: text for a person is dropped,
/// and what a person must read stays on stderr.
class _JsonOutput extends Output {
  final Map<String, Object?> _data = {};
  late final Logger _logger = _OutputLogger(this);
  var _finished = false;

  _JsonOutput(super._base, super.environment, super._out) : super._();

  @override
  OutputMode get mode => OutputMode.json;

  @override
  Logger get logger => _logger;

  /// Nobody is asked anything: a document is not the place for a question.
  @override
  bool get verbose => false;

  @override
  set verbose(bool value) {}

  @override
  void info(String message) {}

  @override
  void success(String message) {}

  @override
  ConflictTerminal terminal(ConflictTerminal base) =>
      const NonInteractiveTerminal();

  @override
  void started(String id) {}

  @override
  void summary(String verb, ChangeCounts counts) {}

  @override
  void data(Map<String, Object?> fields) => _data.addAll(fields);

  @override
  void finish(String command, int exitCode) {
    if (_finished) return;

    _finished = true;
    _out.writeln(
      jsonEncode({
        'schemaVersion': jsonSchemaVersion,
        'command': command,
        'exitCode': exitCode,
        ..._data,
        'warnings': warnings,
        'errors': errors,
        'durationMs': elapsed.inMilliseconds,
      }),
    );
  }
}

/// The logger of the processors and the engine, which follows the rules of the
/// output: in `--json` only warnings and errors get through, to stderr and into
/// the document; on a terminal a spinner never ends up in the middle of a line.
///
/// It covers the lines a processor prints. A progress bar or a question does not
/// go through it, so nothing that runs under it may use them: the 2.x processors
/// are run without theirs (see `Processor.runInstruction`).
class _OutputLogger extends Logger {
  final Output _output;

  /// Whether only warnings and errors get through, as in a dry run, which has
  /// nothing to say about what it does but must not hide a warning.
  final bool _warningsOnly;

  _OutputLogger(this._output, {bool warningsOnly = false})
    : _warningsOnly = warningsOnly,
      super(theme: _output._base.theme);

  Logger get _base => _output._base;

  @override
  Level get level => _base.level;

  @override
  set level(Level value) => _base.level = value;

  /// Takes the spinner away before something is printed, so that the line is
  /// not drawn over it. The next frame draws it again.
  void _clear() {
    if (_output case final _RichOutput rich) {
      if (rich._timer != null) rich._out.write('\r\x1B[2K');
    }
  }

  @override
  void info(String? message, {LogStyle? style}) {
    if (_output.isJson || _warningsOnly) return;

    _clear();
    _base.info(message, style: style);
  }

  @override
  void success(String? message, {LogStyle? style}) {
    if (_output.isJson || _warningsOnly) return;

    _clear();
    _base.success(message, style: style);
  }

  // No `_clear()`: it only prints when verbose, and then nothing is drawn.
  @override
  void detail(String? message, {LogStyle? style}) {
    if (_output.isJson || _warningsOnly) return;

    _base.detail(message, style: style);
  }

  @override
  void write(String? message) {
    if (_output.isJson || _warningsOnly) return;

    _clear();
    _base.write(message);
  }

  @override
  void warn(String? message, {String tag = 'WARN', LogStyle? style}) {
    _clear();
    if (message != null) _output._warnings.add(message);
    _base.warn(message, tag: tag, style: style);
  }

  @override
  void err(String? message, {LogStyle? style}) {
    _clear();
    if (message != null) _output._errors.add(message);
    _base.err(message, style: style);
  }
}

/// A terminal nobody sits at: nothing is asked and nothing is written, which is
/// what conflicts get when stdout is a document.
class NonInteractiveTerminal implements ConflictTerminal {
  /// Creates the terminal.
  const NonInteractiveTerminal();

  @override
  bool get isInteractive => false;

  @override
  bool get supportsColor => false;

  @override
  void write(String text) {}

  @override
  Future<String?> readAnswer(String prompt) async => null;
}
