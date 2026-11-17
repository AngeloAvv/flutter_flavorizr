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

import 'package:flutter_flavorizr/src/entrypoint/cli_context.dart';
import 'package:flutter_flavorizr/src/entrypoint/exit_codes.dart';
import 'package:flutter_flavorizr/src/entrypoint/output/output_environment.dart';
import 'package:flutter_test/flutter_test.dart';

import 'cli_fixture.dart';

final _ansi = RegExp('\x1B');
final _colour = RegExp('\x1B\\[[0-9;]*m');

void main() {
  late CliFixture project;

  setUp(() => project = CliFixture());
  tearDown(() => project.dispose());

  /// Everything the run printed: the lines, and what was drawn.
  String printed() => '${project.logger.output}\n${project.stdout}';

  group('in a log (stdout is not a terminal)', () {
    test('plan has no ANSI code and no animation', () async {
      final code = await project.run(['plan', ...engineTargets]);

      expect(code, ExitCodes.ok);
      expect(printed(), isNot(contains(_ansi)));
      expect(printed(), isNot(contains('\r')));
      expect(project.stdout.toString(), isEmpty);
    });

    test('apply lists the steps by platform, one line each', () async {
      final code = await project.run(['apply', '-y', ...engineTargets]);
      final lines = project.logger.lines;

      expect(code, ExitCodes.ok);
      expect(lines, contains('android'));
      expect(
        lines.where(
          (l) => RegExp(r'^  ok android:\w+ \(\d+ ms\)$').hasMatch(l),
        ),
        hasLength(4),
      );
      expect(printed(), isNot(contains(_ansi)));
      expect(printed(), isNot(contains('\r')));
    });

    test('apply ends with the counts and the time', () async {
      await project.run(['apply', '-y', ...engineTargets]);

      expect(
        project.logger.lines,
        contains(
          matches(RegExp(r'^Applied: \+3 ~2 -0, 0 conflicts \(\d+ ms\)$')),
        ),
      );
      expect(project.logger.lines.last, 'Flavorization process finished');
    });

    test('plan and status end with the counts too', () async {
      await project.run(['plan', ...engineTargets]);
      await project.run(['status', ...engineTargets]);

      expect(
        project.logger.lines,
        containsAll([
          matches(RegExp(r'^Plan: \+3 ~2 -0, 0 conflicts ')),
          matches(RegExp(r'^Status: \+3 ~2 -0, 0 conflicts ')),
        ]),
      );
    });

    test('does not repeat the steps in a summary of what completed', () async {
      await project.run(['apply', '-y', ...engineTargets]);

      expect(project.logger.output, isNot(contains('Completed:')));
    });

    test('the warning of a 2.x option stays a warning, with no ANSI', () async {
      await project.run(['apply', '-f', ...engineTargets]);

      expect(project.logger.warnings, hasLength(1));
      expect(printed(), isNot(contains(_ansi)));
    });

    test('a failure is told once, as an error', () async {
      final code = await project.run(['plan', 'nope']);

      expect(code, ExitCodes.usage);
      expect(project.logger.errors, hasLength(1));
    });
  });

  group('in a terminal', () {
    setUp(() => project.environment = terminal);

    test('plan colours the changes as a diff', () async {
      await project.run(['plan', ...engineTargets]);

      expect(
        project.logger.output,
        contains('\x1B[32m+ android/app/flavorizr.gradle (managed)\x1B[39m'),
      );
      expect(
        project.logger.output,
        contains('\x1B[33m~ android/app/build.gradle (patched)\x1B[39m'),
      );
      expect(
        project.logger.output,
        contains('\x1B[32m+ apple (added)\x1B[39m'),
      );
    });

    test('a deletion is red and a conflict too', () async {
      await project.run(['apply', '-y', ...engineTargets]);
      project.write('android/app/flavorizr.gradle', '// mine\n');
      project.write('flavorizr.yaml', CliFixture.config(['apple']));
      project.logger.lines.clear();

      final code = await project.run(['plan', ...engineTargets]);

      expect(code, ExitCodes.attention);
      expect(
        project.logger.output,
        contains('\x1B[31m- banana (removed)\x1B[39m'),
      );
      expect(
        project.logger.output,
        contains(
          RegExp('\x1B\\[31m~ android/app/flavorizr.gradle .*\\[conflict\\]'),
        ),
      );
    });

    test('apply draws a spinner for each step, and ticks them off', () async {
      final code = await project.run(['apply', '-y', ...engineTargets]);

      expect(code, ExitCodes.ok);
      expect(project.stdout.toString(), contains('\r\x1B[2K'));
      expect(project.stdout.toString(), contains('android:icons'));
      expect(
        project.logger.lines.where((l) => RegExp(r'✓.* android:').hasMatch(l)),
        hasLength(4),
      );
      expect(project.logger.lines, contains('\x1B[1mandroid\x1B[22m'));
    });

    test('apply ends with the counts and the time, coloured', () async {
      await project.run(['apply', '-y', ...engineTargets]);

      expect(
        project.logger.lines,
        contains(
          allOf(
            contains('Applied'),
            contains('\x1B[32m+3\x1B[39m'),
            contains('\x1B[33m~2\x1B[39m'),
            contains('\x1B[31m-0\x1B[39m'),
          ),
        ),
      );
    });

    test('plan shows that it is working out the changes', () async {
      await project.run(['plan', ...engineTargets]);

      expect(project.stdout.toString(), contains('Working out the changes'));
    });

    test('--verbose does not draw over what the processors print', () async {
      await project.run(['apply', '-y', '-v', ...engineTargets]);

      expect(project.stdout.toString(), isEmpty);
      expect(project.logger.output, contains(RegExp(r'✓.* android:icons')));
    });

    test('NO_COLOR takes the colour away and keeps the animation', () async {
      project.environment = OutputEnvironment(
        stdoutIsTerminal: true,
        stderrIsTerminal: true,
        stdinIsTerminal: true,
        supportsAnsi: true,
        variables: {'NO_COLOR': '1'},
      );

      await project.run(['apply', '-y', ...engineTargets]);
      await project.run(['plan', ...engineTargets]);

      expect(printed(), isNot(contains(_colour)));
      expect(project.stdout.toString(), contains('\r\x1B[2K'));
      expect(project.logger.output, contains('+ android/app/flavorizr.gradle'));
    });

    test('a CI that has a terminal gets a log', () async {
      project.environment = OutputEnvironment(
        stdoutIsTerminal: true,
        stderrIsTerminal: true,
        stdinIsTerminal: true,
        supportsAnsi: true,
        variables: {'CI': 'true'},
      );

      await project.run(['apply', '-y', ...engineTargets]);

      expect(printed(), isNot(contains(_ansi)));
      expect(project.stdout.toString(), isEmpty);
    });

    test('a redirected stderr gives a log too', () async {
      project.environment = const OutputEnvironment(
        stdoutIsTerminal: true,
        stderrIsTerminal: false,
        stdinIsTerminal: true,
        supportsAnsi: true,
      );

      await project.run(['plan', ...engineTargets]);

      expect(printed(), isNot(contains(_ansi)));
    });

    test('the refusal of a removal keeps working', () async {
      await project.run(['apply', '-y', ...engineTargets]);
      project.write('flavorizr.yaml', 'flavors: {}\n');

      final code = await project.run(['plan', ...engineTargets]);

      expect(code, ExitCodes.data);
      expect(project.logger.errors, hasLength(1));
    });
  });

  group('the confirmation', () {
    CliContext contextOf(OutputEnvironment environment) => CliContext(
      projectRoot: project.root,
      logger: project.logger,
      environment: environment,
    );

    test('is not asked without a terminal: it goes on', () async {
      final answer = await contextOf(
        const OutputEnvironment.plain(),
      ).confirm('Do you want to proceed?');

      expect(answer, isTrue);
      expect(project.logger.lines, isEmpty);
    });

    test('is not asked of a stdin that is not a terminal either', () async {
      final answer = await contextOf(
        const OutputEnvironment(
          stdoutIsTerminal: true,
          stderrIsTerminal: true,
          stdinIsTerminal: false,
          supportsAnsi: true,
        ),
      ).confirm('Do you want to proceed?');

      expect(answer, isTrue);
    });
  });
}
