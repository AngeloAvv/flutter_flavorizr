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

@Timeout(Duration(minutes: 5))
library;

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

void _copy(Directory from, Directory to) {
  to.createSync(recursive: true);

  for (final entity in from.listSync(followLinks: false)) {
    final target =
        '${to.path}/${entity.uri.pathSegments.where((s) => s.isNotEmpty).last}';

    if (entity is Directory) {
      _copy(entity, Directory(target));
    } else if (entity is File) {
      entity.copySync(target);
    }
  }
}

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

    group('has a dartdoc for every symbol it exports', () {
      // The rule is not on for the package, which has far more public members
      // than the API: the files of the API are analyzed in a copy of it that
      // has the rule on.
      late Directory copy;

      setUpAll(() async {
        copy = Directory.systemTemp.createTempSync('public_api_');
        _copy(Directory('lib'), Directory('${copy.path}/lib'));
        File('pubspec.yaml').copySync('${copy.path}/pubspec.yaml');
        File('pubspec.lock').copySync('${copy.path}/pubspec.lock');
        File('${copy.path}/analysis_options.yaml').writeAsStringSync(
          'include: package:flutter_lints/flutter.yaml\n'
          'linter:\n  rules:\n    public_member_api_docs: true\n',
        );
        File(
          '${copy.path}/lib/undocumented.dart',
        ).writeAsStringSync('class Undocumented {}\n');

        final result = await Process.run(
          'flutter',
          ['pub', 'get', '--offline'],
          workingDirectory: copy.path,
          runInShell: Platform.isWindows,
        );

        expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      });

      tearDownAll(() => copy.deleteSync(recursive: true));

      /// What the analyzer says about [files] of the copy.
      Future<({int code, String output})> analyze(
        Iterable<String> files,
      ) async {
        // `dart` of the PATH: in a test, the resolved executable is the tester.
        final result = await Process.run(
          'dart',
          ['analyze', ...files],
          workingDirectory: copy.path,
          runInShell: Platform.isWindows,
        );

        return (code: result.exitCode, output: '${result.stdout}');
      }

      List<String> missing(String output) => [
        for (final line in output.split('\n'))
          if (line.contains('public_member_api_docs')) line,
      ];

      test('as the analyzer sees it', () async {
        final result = await analyze({
          'lib/flutter_flavorizr.dart',
          'lib/experimental.dart',
          ..._exportedFiles('lib/flutter_flavorizr.dart'),
          ..._exportedFiles('lib/experimental.dart'),
        });

        // It did run (0: nothing to say, 1: it said something).
        expect(result.code, anyOf(0, 1), reason: result.output);
        expect(result.output, contains('Analyzing'), reason: result.output);
        expect(missing(result.output), isEmpty, reason: result.output);
      }, timeout: const Timeout(Duration(minutes: 5)));

      test('and the check does see a symbol that has none', () async {
        final result = await analyze(['lib/undocumented.dart']);

        expect(missing(result.output), isNotEmpty, reason: result.output);
      }, timeout: const Timeout(Duration(minutes: 5)));
    });

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
