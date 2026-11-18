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

// Golden parity harness: records the output of a flavorizr version on a fresh
// Flutter project and checks later versions against it.
//
//   dart run tool/parity.dart record --flavorizr 2.6.0 --golden tool/parity/golden/2.6.0
//   dart run tool/parity.dart check  --flavorizr . --golden tool/parity/golden/2.6.0
//
// See tool/parity/README.md.

import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

import 'parity/src/differ.dart';
import 'parity/src/golden.dart';
import 'parity/src/runner.dart';

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption(
      'flavorizr',
      help: 'A flavorizr version on pub.dev (2.6.0) or the path of a checkout.',
      defaultsTo: '2.6.0',
    )
    ..addOption(
      'golden',
      help: 'Directory of the golden.',
      defaultsTo: 'tool/parity/golden/2.6.0',
    )
    ..addOption(
      'whitelist',
      help: 'YAML file listing the intended differences, each with a reason.',
      defaultsTo: 'tool/parity/whitelist.yaml',
    )
    ..addOption(
      'flutter',
      help: 'The Flutter executable.',
      defaultsTo: 'flutter',
    )
    ..addOption(
      'fixtures',
      help:
          'Folder with the flavorizr.yaml used to flavorize the project and '
          'a files/ folder copied in its root.',
      defaultsTo: p.join('tool', 'parity', 'fixtures'),
    );

  final ArgResults results;
  try {
    results = parser.parse(arguments);
  } on FormatException catch (e) {
    stderr.writeln('${e.message}\n\n${_usage(parser)}');
    exit(64);
  }

  final command = results.rest.firstOrNull;
  if (command != 'record' && command != 'check') {
    stderr.writeln(_usage(parser));
    exit(64);
  }

  final fixtures = Directory(results['fixtures'] as String);
  final fixtureFor3x = File(p.join(fixtures.path, 'flavorizr.3.yaml'));
  final runner = ParityRunner(
    fixture: File(p.join(fixtures.path, 'flavorizr.yaml')),
    fixtureFiles: Directory(p.join(fixtures.path, 'files')),
    // Optional: a fixture directory without it uses its flavorizr.yaml for both.
    fixtureFor3x: fixtureFor3x.existsSync() ? fixtureFor3x : null,
    flutter: results['flutter'] as String,
  );
  final golden = Golden(Directory(results['golden'] as String));
  final source = FlavorizrSource(results['flavorizr'] as String);

  try {
    if (command == 'record') {
      await golden.record(runner, source);
      stdout.writeln('Golden recorded in ${golden.directory.path}');
      return;
    }

    final report = await golden.check(
      runner,
      source,
      whitelist: _whitelist(results),
    );

    stdout.write(report.describe());
    if (report.isClean) {
      stdout.writeln(
        'Parity OK: ${report.differences.length} whitelisted difference(s).',
      );
    } else {
      stderr.writeln('Parity broken: see the differences above.');
      exit(1);
    }
  } on StateError catch (e) {
    stderr.writeln(e.message);
    exit(2);
  } on FormatException catch (e) {
    stderr.writeln(e.message);
    exit(2);
  } on ProcessException catch (e) {
    stderr.writeln(
      '`${e.executable} ${e.arguments.join(' ')}` failed:\n'
      '${e.message}',
    );
    exit(2);
  }
}

/// The default whitelist is optional, one asked for by name must exist.
Whitelist _whitelist(ArgResults results) {
  final file = File(results['whitelist'] as String);
  if (!file.existsSync()) {
    if (results.wasParsed('whitelist')) {
      throw FormatException('Whitelist not found: ${file.path}');
    }
    return const Whitelist.empty();
  }
  return Whitelist.parse(file.readAsStringSync());
}

String _usage(ArgParser parser) =>
    'Usage: dart run tool/parity.dart <record|check> [options]\n\n'
    '${parser.usage}';
