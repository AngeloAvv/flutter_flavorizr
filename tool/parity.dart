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
      'fixture',
      help: 'The flavorizr.yaml used to flavorize the project.',
      defaultsTo: p.join('tool', 'parity', 'fixtures', 'flavorizr.yaml'),
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

  final runner = ParityRunner(
    fixture: File(results['fixture'] as String),
    flutter: results['flutter'] as String,
  );
  final golden = Golden(Directory(results['golden'] as String));
  final source = FlavorizrSource(results['flavorizr'] as String);

  if (command == 'record') {
    await golden.record(runner, source);
    stdout.writeln('Golden recorded in ${golden.directory.path}');
    return;
  }

  final whitelistFile = File(results['whitelist'] as String);
  final report = await golden.check(
    runner,
    source,
    whitelist: whitelistFile.existsSync()
        ? Whitelist.parse(whitelistFile.readAsStringSync())
        : const Whitelist.empty(),
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
}

String _usage(ArgParser parser) =>
    'Usage: dart run tool/parity.dart <record|check> [options]\n\n'
    '${parser.usage}';
