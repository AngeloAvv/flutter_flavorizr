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

import 'package:flutter_flavorizr/src/entrypoint/exit_codes.dart';
import 'package:flutter_test/flutter_test.dart';

import 'cli_fixture.dart';

/// The `lib/flavors.dart` 2.x generated: it does not export `flavors.g.dart`.
const _old = 'enum Flavor { apple }\n';

final _ansi = RegExp('\x1B');

void main() {
  late CliFixture project;

  setUp(() {
    project = CliFixture();
    project.write('lib/main.dart', 'void main() {}\n');
    project.write('lib/flavors.dart', _old);
  });
  tearDown(() => project.dispose());

  /// The warning is one: on stderr, in the layer, whatever the mode.
  void expectWarned() {
    expect(project.logger.warnings, hasLength(1));
    expect(project.logger.warnings.single, contains('flavors.g.dart'));
    expect(project.logger.warnings.single, contains('lib/flavors.dart'));
  }

  for (final command in ['plan', 'status', 'apply']) {
    final args = [command, if (command == 'apply') '-y', 'flutter:flavors'];

    group(command, () {
      test('warns in a log', () async {
        await project.run(args);

        expectWarned();
        expect(project.logger.output, isNot(contains(_ansi)));
        expect(project.read('lib/flavors.dart'), _old);
      });

      test('warns in a terminal', () async {
        project.environment = terminal;

        await project.run(args);

        expectWarned();
      });

      test('warns with --json, on stderr and in the document', () async {
        final code = await project.run([...args, '--json']);
        final doc = jsonDecode(project.stdout.toString()) as Map;

        expect(code, anyOf(ExitCodes.ok, ExitCodes.attention));
        expectWarned();
        expect(doc['warnings'], project.logger.warnings);
        expect(project.stdout.toString().trimRight().split('\n'), hasLength(1));
      });
    });
  }

  test('a dry run does not say anything else about what it did', () async {
    await project.run(['plan', 'flutter:flavors']);

    expect(project.logger.output, isNot(contains('Completed:')));
  });
}
