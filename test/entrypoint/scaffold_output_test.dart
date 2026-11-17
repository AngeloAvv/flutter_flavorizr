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

import 'package:flutter_flavorizr/src/entrypoint/exit_codes.dart';
import 'package:flutter_test/flutter_test.dart';

import 'cli_fixture.dart';
import 'output/json_schema_validator.dart';

final _schema =
    jsonDecode(
          File('doc/schemas/flavorizr-output.schema.json').readAsStringSync(),
        )
        as Map<String, Object?>;

/// `--overwrite-scaffold` goes through the output layer, in every mode.
void main() {
  late CliFixture project;

  setUp(() {
    project = CliFixture();
    project.write('lib/main.dart', 'void main() {}\n');
  });
  tearDown(() => project.dispose());

  Map<String, Object?> document() {
    final doc = jsonDecode(project.stdout.toString()) as Map<String, Object?>;

    expect(validateJson(doc, _schema), isEmpty);

    return doc;
  }

  test('plan --json shows the scaffold file it would replace', () async {
    final code = await project.run([
      'plan',
      '--json',
      '--overwrite-scaffold',
      'flutter:scaffold',
    ]);
    final changes = (document()['changes'] as List).cast<Map>();

    expect(code, ExitCodes.ok);
    expect(
      changes.singleWhere((c) => c['path'] == 'lib/main.dart'),
      containsPair('ownership', 'scaffold'),
    );
    expect(
      changes.singleWhere((c) => c['path'] == 'lib/main.dart'),
      containsPair('change', 'modified'),
    );
  });

  test('plan --json leaves the scaffold file alone without it', () async {
    await project.run(['plan', '--json', 'flutter:scaffold']);

    expect(
      (document()['changes'] as List).cast<Map>().map((c) => c['path']),
      isNot(contains('lib/main.dart')),
    );
  });

  test('apply --json --overwrite-scaffold writes it, and says so', () async {
    final code = await project.run([
      'apply',
      '--json',
      '--overwrite-scaffold',
      'flutter:scaffold',
    ]);

    expect(code, ExitCodes.ok, reason: project.logger.output);
    expect(document()['applied'], isTrue);
    expect(project.read('lib/main.dart'), contains('runApp(const App());'));
  });

  test('in a terminal the replacement is a coloured change', () async {
    project.environment = terminal;

    await project.run(['plan', '--overwrite-scaffold', 'flutter:scaffold']);

    expect(
      project.logger.output,
      contains('\x1B[33m~ lib/main.dart (scaffold)\x1B[39m'),
    );
  });
}
