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

import 'package:flutter_test/flutter_test.dart';

import 'json_schema_validator.dart';

/// The schema and the document that describes it are what a consumer of
/// `--json` reads: they must agree with each other, and with the output.
void main() {
  final schema =
      jsonDecode(
            File('doc/schemas/flavorizr-output.schema.json').readAsStringSync(),
          )
          as Map<String, Object?>;
  final doc = File('doc/json-output.md').readAsStringSync();
  final examples = [
    for (final match in RegExp(
      r'```json\n(.*?)\n```',
      dotAll: true,
    ).allMatches(doc))
      match.group(1)!,
  ];

  test('the document shows an example of every command and of a failure', () {
    final commands = {
      for (final example in examples)
        (jsonDecode(example) as Map<String, Object?>)['command'],
    };

    expect(commands, {'plan', 'apply', 'status', 'list'});
    expect(examples.length, greaterThanOrEqualTo(5));
  });

  for (final example in examples) {
    final name = (jsonDecode(example) as Map<String, Object?>);

    test('the example of ${name['command']} (exit ${name['exitCode']}) holds '
        'to the schema', () {
      expect(validateJson(jsonDecode(example), schema), isEmpty);
    });
  }

  group('the schema', () {
    Map<String, Object?> plan() =>
        jsonDecode(examples.firstWhere((e) => e.contains('"command":"plan"')))
            as Map<String, Object?>;

    test('refuses a document of another version', () {
      expect(validateJson(plan()..['schemaVersion'] = 2, schema), isNotEmpty);
    });

    test('refuses a command it does not know', () {
      expect(validateJson(plan()..['command'] = 'doctor', schema), isNotEmpty);
    });

    test('refuses an exit code flavorizr does not use', () {
      expect(validateJson(plan()..['exitCode'] = 2, schema), isNotEmpty);
    });

    test('refuses a plan that went through and has no changes', () {
      expect(validateJson(plan()..remove('changes'), schema), isNotEmpty);
    });

    test('lets a plan that failed be short', () {
      final failed = {
        'schemaVersion': 1,
        'command': 'plan',
        'exitCode': 65,
        'warnings': <String>[],
        'errors': ['no'],
        'durationMs': 1,
      };

      expect(validateJson(failed, schema), isEmpty);
    });

    test('refuses a change that is not added, modified or deleted', () {
      final document = plan();

      ((document['changes'] as List).first as Map)['change'] = 'moved';

      expect(validateJson(document, schema), isNotEmpty);
    });

    test('refuses a step with no duration', () {
      final apply =
          jsonDecode(
                examples.firstWhere((e) => e.contains('"command":"apply"')),
              )
              as Map<String, Object?>;

      ((apply['steps'] as List).first as Map).remove('durationMs');

      expect(validateJson(apply, schema), isNotEmpty);
    });

    test('lets a consumer meet a field it does not know', () {
      expect(validateJson(plan()..['future'] = true, schema), isEmpty);
    });
  });
}
