/*
 * Copyright (c) 2024 Angelo Cassano
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

import 'package:flutter_test/flutter_test.dart';

/// The files `lib/flutter_flavorizr.dart` and `lib/experimental.dart` export.
List<String> _exportedFiles(String library) => [
  for (final match in RegExp(
    r"^export 'src/([^']+)'",
    multiLine: true,
  ).allMatches(File(library).readAsStringSync()))
    'lib/src/${match.group(1)}',
];

void main() {
  group('the public API', () {
    test('exports files that exist', () {
      for (final library in [
        'lib/flutter_flavorizr.dart',
        'lib/experimental.dart',
      ]) {
        final files = _exportedFiles(library);

        expect(files, isNotEmpty, reason: library);
        for (final file in files) {
          expect(File(file).existsSync(), isTrue, reason: file);
        }
      }
    });

    test('has a dartdoc for every symbol it exports', () async {
      final files = {
        'lib/flutter_flavorizr.dart',
        'lib/experimental.dart',
        ..._exportedFiles('lib/flutter_flavorizr.dart'),
        ..._exportedFiles('lib/experimental.dart'),
      };

      // `dart` of the PATH: in a test, the resolved executable is the tester.
      final result = await Process.run('dart', [
        'analyze',
        '--options=tool/analysis_options_api.yaml',
        ...files,
      ]);
      final missing = '${result.stdout}'
          .split('\n')
          .where((line) => line.contains('public_member_api_docs'))
          .toList();

      expect(missing, isEmpty, reason: missing.join('\n'));
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('says it is experimental where it is', () {
      expect(
        File('lib/experimental.dart').readAsStringSync(),
        contains('**Experimental**'),
      );
      expect(
        File('lib/flutter_flavorizr.dart').readAsStringSync(),
        contains('**stable**'),
      );
    });
  });
}
