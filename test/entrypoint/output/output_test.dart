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

import 'package:flutter_flavorizr/src/entrypoint/output/output.dart';
import 'package:flutter_flavorizr/src/entrypoint/output/output_environment.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mason_logger/mason_logger.dart';

import '../cli_fixture.dart';

const _terminal = OutputEnvironment(
  stdoutIsTerminal: true,
  stderrIsTerminal: true,
  stdinIsTerminal: true,
  supportsAnsi: true,
);

final _ansi = RegExp('\x1B');

/// Runs [body] as the step [id], telling [out] how it went like the engine does.
Future<T> runStep<T>(Output out, String id, Future<T> Function() body) async {
  final stopwatch = Stopwatch()..start();

  out.started(id);

  try {
    final result = await body();

    out.finished(id, stopwatch.elapsed);

    return result;
  } on Object catch (error) {
    out.failed(id, stopwatch.elapsed, error);

    rethrow;
  }
}

void main() {
  late RecordingLogger logger;
  late StringBuffer sink;

  setUp(() {
    logger = RecordingLogger();
    sink = StringBuffer();
  });

  Output output({
    OutputEnvironment environment = const OutputEnvironment.plain(),
    bool json = false,
  }) => Output.create(
    logger: logger,
    environment: environment,
    json: json,
    sink: sink,
    frameInterval: const Duration(milliseconds: 5),
  );

  group('the mode', () {
    test('is plain when stdout is not a terminal', () {
      expect(output().mode, OutputMode.plain);
    });

    test('is rich on a terminal', () {
      expect(output(environment: _terminal).mode, OutputMode.rich);
    });

    test('is plain on a terminal of a CI', () {
      final ci = OutputEnvironment(
        stdoutIsTerminal: true,
        stderrIsTerminal: true,
        stdinIsTerminal: true,
        supportsAnsi: true,
        variables: {'CI': 'true'},
      );

      expect(output(environment: ci).mode, OutputMode.plain);
    });

    test('is json when asked, on a terminal too', () {
      expect(output(json: true).mode, OutputMode.json);
      expect(output(environment: _terminal, json: true).mode, OutputMode.json);
    });
  });

  group('plain', () {
    test('prints lines through the logger and nothing else', () {
      final out = output();

      out.info('a');
      out.success('b');
      out.warn('c');
      out.err('d');

      expect(logger.lines, ['a', 'b', 'c', 'd']);
      expect(logger.warnings, ['c']);
      expect(logger.errors, ['d']);
      expect(sink.toString(), isEmpty);
    });

    test('lists the steps by platform, linearly', () async {
      final out = output();

      for (final id in ['android:icons', 'android:manifest', 'ios:plist']) {
        await runStep(out, id, () async {});
      }

      expect(logger.lines, [
        'android',
        matches(RegExp(r'^  ok android:icons \(\d+ ms\)$')),
        matches(RegExp(r'^  ok android:manifest \(\d+ ms\)$')),
        'ios',
        matches(RegExp(r'^  ok ios:plist \(\d+ ms\)$')),
      ]);
      expect(sink.toString(), isEmpty);
    });

    test('says which step failed, and rethrows', () async {
      final out = output();
      final error = StateError('boom');

      await expectLater(
        runStep(out, 'android:icons', () async => throw error),
        throwsA(same(error)),
      );

      expect(logger.lines.last, matches(RegExp(r'^  failed android:icons ')));
      expect(out.steps.single.status, StepStatus.failed);
    });

    test('has no ANSI code, whatever it prints', () async {
      final out = output();

      await runStep(out, 'android:icons', () async {});
      out.summary('Plan', const ChangeCounts(added: 1));
      out.success('done');

      expect(logger.output, isNot(contains(_ansi)));
      expect(sink.toString(), isNot(contains(_ansi)));
    });

    test('ends with the counts and the time', () {
      output().summary(
        'Plan',
        const ChangeCounts(added: 3, modified: 2, deleted: 1, conflicts: 1),
      );

      expect(
        logger.lines.single,
        matches(RegExp(r'^Plan: \+3 ~2 -1, 1 conflict \(\d+ ms\)$')),
      );
    });

    test('does not draw anything while it works', () async {
      final result = await output().busy('Planning', () async => 42);

      expect(result, 42);
      expect(sink.toString(), isEmpty);
    });

    test('has no document', () {
      final out = output()..data({'a': 1});

      out.finish('plan', 0);

      expect(sink.toString(), isEmpty);
    });

    test('is verbose when asked', () {
      final out = output();

      expect(out.verbose, isFalse);
      out.verbose = true;
      expect(out.verbose, isTrue);
      expect(logger.level, Level.verbose);
    });
  });

  group('rich', () {
    test(
      'draws a spinner while a step runs, and a tick when it is done',
      () async {
        final out = output(environment: _terminal);

        await runStep(out, 'android:icons', () async {
          await Future<void>.delayed(const Duration(milliseconds: 40));
        });

        final drawn = sink.toString();

        expect(drawn, contains('\r\x1B[2K'));
        expect(drawn, contains('android:icons'));
        expect(RegExp('[⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏]').allMatches(drawn).length, greaterThan(1));
        expect(logger.lines, [
          '\x1B[1mandroid\x1B[22m',
          matches(RegExp(r'^  \x1B\[32m✓\x1B\[39m android:icons ')),
        ]);
      },
    );

    test('takes the spinner away when a step fails', () async {
      final out = output(environment: _terminal);

      await expectLater(
        runStep(out, 'android:icons', () async => throw StateError('boom')),
        throwsStateError,
      );

      expect(sink.toString(), endsWith('\r\x1B[2K'));
      expect(logger.lines.last, contains('✗'));
    });

    test('stops drawing once the step is done', () async {
      final out = output(environment: _terminal);

      await runStep(out, 'android:icons', () async {});
      final drawn = sink.toString();
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(sink.toString(), drawn);
    });

    test('shows a spinner for work that leaves no trace', () async {
      final out = output(environment: _terminal);

      await out.busy('Working out the changes', () async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });

      expect(sink.toString(), contains('Working out the changes'));
      expect(sink.toString(), endsWith('\r\x1B[2K'));
      expect(logger.lines, isEmpty);
      expect(out.steps, isEmpty);
    });

    test('colours the counts of the summary', () {
      output(environment: _terminal).summary(
        'Applied',
        const ChangeCounts(added: 3, modified: 2, deleted: 1),
      );

      expect(
        logger.lines.single,
        allOf(
          contains('\x1B[32m+3\x1B[39m'),
          contains('\x1B[33m~2\x1B[39m'),
          contains('\x1B[31m-1\x1B[39m'),
          contains('in '),
        ),
      );
    });

    test('has no colour with NO_COLOR, but still animates', () async {
      final out = output(
        environment: OutputEnvironment(
          stdoutIsTerminal: true,
          stderrIsTerminal: true,
          stdinIsTerminal: true,
          supportsAnsi: true,
          variables: {'NO_COLOR': '1'},
        ),
      );

      await runStep(out, 'android:icons', () async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      out.summary('Plan', const ChangeCounts(added: 1));

      expect(out.mode, OutputMode.rich);
      // Colour codes end with `m`: what is left is the line being redrawn.
      expect(logger.output, isNot(contains(RegExp('\x1B\\[[0-9;]*m'))));
      expect(sink.toString(), isNot(contains(RegExp('\x1B\\[[0-9;]*m'))));
      expect(sink.toString(), contains('\r\x1B[2K'));
    });

    test('does not draw over what the processors print', () async {
      final out = output(environment: _terminal)..verbose = true;

      await runStep(out, 'android:icons', () async {
        out.logger.detail('writing');
      });

      expect(sink.toString(), isEmpty);
      expect(logger.lines, contains('writing'));
    });

    test('clears the spinner before a warning of the engine', () async {
      final out = output(environment: _terminal);

      await runStep(out, 'android:icons', () async {
        out.logger.warn('slow');
        await Future<void>.delayed(const Duration(milliseconds: 10));
      });

      expect(logger.warnings, ['slow']);
      expect(sink.toString(), contains('\r\x1B[2K'));
    });
  });

  group('json', () {
    Map<String, Object?> document(Output out, {int code = 0}) {
      out.finish('plan', code);

      return jsonDecode(sink.toString()) as Map<String, Object?>;
    }

    test('prints one document, on one line, and nothing else', () async {
      final out = output(json: true);

      out.info('hello');
      out.success('done');
      out.logger.detail('what');
      out.data({'processors': <Object?>[]});
      final doc = document(out);

      expect(sink.toString().trim().split('\n'), hasLength(1));
      expect(sink.toString(), endsWith('\n'));
      expect(doc['schemaVersion'], jsonSchemaVersion);
      expect(doc['command'], 'plan');
      expect(doc['exitCode'], 0);
      expect(doc['processors'], isEmpty);
      expect(logger.lines, isEmpty);
    });

    test('keeps warnings and errors on stderr, and in the document', () {
      final out = output(json: true);

      out.warn('careful');
      out.err('wrong');
      final doc = document(out, code: 65);

      expect(logger.warnings, ['careful']);
      expect(logger.errors, ['wrong']);
      expect(doc['warnings'], ['careful']);
      expect(doc['errors'], ['wrong']);
      expect(doc['exitCode'], 65);
    });

    test('lets only warnings and errors of the engine through', () {
      final out = output(json: true);

      out.logger.info('a');
      out.logger.success('b');
      out.logger.detail('c');
      out.logger.write('d');
      out.logger.warn('e');
      out.logger.err('f');
      final doc = document(out);

      expect(logger.lines, ['e', 'f']);
      expect(doc['warnings'], ['e']);
      expect(doc['errors'], ['f']);
    });

    test('ignores --verbose, which would print on stdout', () {
      final out = output(json: true)..verbose = true;

      out.logger.detail('writing');

      expect(out.verbose, isFalse);
      expect(logger.lines, isEmpty);
    });

    test('asks nothing', () {
      final terminal = output(json: true).terminal(NoTerminal());

      expect(terminal.isInteractive, isFalse);
      expect(terminal.supportsColor, isFalse);
    });

    test('records the steps, without printing them', () async {
      final out = output(json: true);

      await runStep(out, 'android:icons', () async {});
      out.finish('apply', 0);

      expect(logger.lines, isEmpty);
      expect(out.steps.single.id, 'android:icons');
    });

    test('has no ANSI code', () {
      final out = output(environment: _terminal, json: true);

      out.warn('careful');
      out.finish('plan', 0);

      expect(sink.toString(), isNot(contains(_ansi)));
    });

    test('prints the document once', () {
      final out = output(json: true);

      out.finish('plan', 0);
      out.finish('plan', 1);

      expect(sink.toString().trim().split('\n'), hasLength(1));
    });
  });

  test('a duration is read by a person', () {
    expect(formatDuration(const Duration(milliseconds: 12)), '12 ms');
    expect(formatDuration(const Duration(milliseconds: 1200)), '1.2 s');
    expect(formatDuration(const Duration(seconds: 65)), '1 m 5 s');
  });

  test('a platform is what comes before the colon', () {
    expect(platformOfProcessor('android:icons'), 'android');
    expect(platformOfProcessor('ide:config'), 'ide');
    expect(platformOfProcessor('alone'), 'alone');
  });
}
