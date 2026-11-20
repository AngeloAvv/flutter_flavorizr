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

import 'package:flutter_flavorizr/src/engine/adopt/dummy_assets.dart';
import 'package:flutter_flavorizr/src/engine/conflict/conflict_terminal.dart';
import 'package:flutter_flavorizr/src/entrypoint/cli_context.dart';
import 'package:flutter_flavorizr/src/entrypoint/output/output_environment.dart';
import 'package:flutter_flavorizr/src/entrypoint/processor_registry.dart';
import 'package:flutter_flavorizr/src/entrypoint/run.dart' as cli;
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

/// A logger that keeps what it is asked to print, whatever the level.
class RecordingLogger extends Logger {
  final List<String> lines = [];
  final List<String> errors = [];
  final List<String> warnings = [];

  RecordingLogger() : super(level: Level.quiet);

  /// Everything that was printed.
  String get output => lines.join('\n');

  @override
  void info(String? message, {LogStyle? style}) => lines.add('$message');

  @override
  void err(String? message, {LogStyle? style}) {
    lines.add('$message');
    errors.add('$message');
  }

  @override
  void warn(String? message, {String tag = 'WARN', LogStyle? style}) {
    lines.add('$message');
    warnings.add('$message');
  }

  @override
  void success(String? message, {LogStyle? style}) => lines.add('$message');

  @override
  void detail(String? message, {LogStyle? style}) {
    if (level == Level.verbose) lines.add('$message');
  }
}

/// A terminal nobody sits at.
class NoTerminal implements ConflictTerminal {
  @override
  bool get isInteractive => false;

  @override
  bool get supportsColor => false;

  @override
  void write(String text) {}

  @override
  Future<String?> readAnswer(String prompt) async => null;
}

/// The processors that run on the engine, which together are a full run of it:
/// only a full run records the flavors in the lock.
const engineTargets = [
  'flutter:flavors',
  'android:androidManifest',
  'android:buildGradle',
  'android:dummyAssets',
  'android:icons',
];

/// A terminal that shows colour and animation.
const terminal = OutputEnvironment(
  stdoutIsTerminal: true,
  stderrIsTerminal: true,
  stdinIsTerminal: true,
  supportsAnsi: true,
);

const _manifest = '''
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application
        android:label="example"
        android:name="\${applicationName}">
    </application>
</manifest>
''';

const _buildGradle = '''
plugins {
    id "com.android.application"
}

android {
    namespace "com.example.app"
}
''';

/// A throwaway Flutter project with an Android folder, and what it takes to run
/// a command in it.
class CliFixture {
  final Directory root = Directory.systemTemp.createTempSync('flavorizr_cli_');
  final RecordingLogger logger = RecordingLogger();
  final List<String> questions = [];

  /// What the user answers when asked to confirm.
  bool answer = true;

  /// What the user answers to a question that has a default, by question: the
  /// default when it is not here.
  final Map<String, String> answers = {};

  /// The questions the user was asked, with a default answer.
  final List<String> prompts = [];

  /// What happens while the user is asked a question.
  void Function(String question)? whileAsking;

  /// What stdout holds: the JSON document of `--json`, and what is drawn on a
  /// terminal.
  final StringBuffer stdout = StringBuffer();

  /// What the process looks like: a pipe, as in a CI, unless a test says so.
  OutputEnvironment environment = const OutputEnvironment.plain();

  String? flutterVersion = '3.47.9';

  /// The processors the commands know, the standard ones unless a test says so.
  ProcessorRegistry? registry;

  /// The placeholder assets of 2.x, the real ones unless a test says so.
  DummyAssets? dummyAssets;

  CliFixture({
    bool android = true,
    Iterable<String> flavors = const ['apple', 'banana'],
    String extraConfig = '',
  }) {
    write('pubspec.yaml', 'name: app\n');
    write('flavorizr.yaml', config(flavors, extra: extraConfig));

    if (android) {
      write('android/app/src/main/AndroidManifest.xml', _manifest);
      write('android/app/build.gradle', _buildGradle);
    }
  }

  /// A configuration with an Android flavor for each of [flavors].
  static String config(Iterable<String> flavors, {String extra = ''}) =>
      'flavors:\n${[for (final flavor in flavors) '''
  $flavor:
    app:
      name: "$flavor app"
    android:
      applicationId: "com.example.$flavor"
'''].join()}$extra';

  /// The context the commands run in.
  CliContext get context => CliContext(
    projectRoot: root,
    logger: logger,
    terminal: NoTerminal(),
    confirm: (question) async {
      questions.add(question);

      return answer;
    },
    prompt: (question, {required defaultValue}) async {
      prompts.add(question);
      whileAsking?.call(question);

      return answers[question] ?? defaultValue;
    },
    registry: registry,
    flutterVersion: () async => flutterVersion,
    environment: environment,
    sink: stdout,
    version: '3.0.0',
    dummyAssets: dummyAssets,
  );

  /// Runs the command line [args] and returns its exit code.
  Future<int> run(List<String> args) => cli.run(args, context: context);

  String abs(String path) => p.joinAll([root.path, ...p.split(path)]);

  void write(String path, String content) {
    final file = File(abs(path));

    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
  }

  String read(String path) => File(abs(path)).readAsStringSync();

  bool exists(String path) =>
      FileSystemEntity.typeSync(abs(path)) != FileSystemEntityType.notFound;

  /// The text of every file of the project, by path, to tell whether anything
  /// changed.
  Map<String, String> snapshot() => {
    for (final file in root.listSync(recursive: true).whereType<File>())
      p.relative(file.path, from: root.path): file.readAsStringSync(),
  };

  void dispose() => root.deleteSync(recursive: true);
}
