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

// End to end check of one platform, which CI runs once for each of them:
//
//   dart run tool/e2e.dart <android|ios|macos|linux|windows>
//
// It creates a Flutter project in a temp dir, flavorizes it with this checkout
// and checks what the user of flavorizr counts on:
//
// 1. `apply` works on a project `flutter create` made;
// 2. `plan` then has nothing to do: a second run is idempotent;
// 3. a flavor that is dropped from flavorizr.yaml is removed by `apply`, and a
//    second `plan` has nothing to do again;
// 4. the flavor that is left builds;
// 5. on iOS and macOS, the build, which makes Flutter inject its Swift Package
//    Manager pre-action into the schemes it finds without one, changes nothing
//    for flavorizr, and the scheme of the flavor has that pre-action once.
//
// The files of the project are the ones `flutter create` writes, so a change of
// Flutter that a processor does not follow is found here.

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

const _platforms = ['android', 'ios', 'macos', 'linux', 'windows'];

/// What each flavor says about [platform].
const _platformSection = {
  // `customConfig` and `manifestPlaceholders` are written in Kotlin here, as
  // `flutter create` makes a Kotlin project, and in Groovy by the tests.
  'android':
      'android:\n      applicationId: "com.example.%s"'
      '\n      customConfig:\n        versionNameSuffix: "-%s"'
      '\n        matchingFallbacks: [release]'
      '\n      manifestPlaceholders:\n        flavorScheme: "%s"',
  'ios': 'ios:\n      bundleId: "com.example.%s"',
  'macos': 'macos:\n      bundleId: "com.example.%s"',
  'linux': 'linux:\n      applicationId: "com.example.%s"',
  'windows': 'windows: {}',
};

/// The command that builds the flavor on each platform.
const _build = {
  'android': ['build', 'appbundle', '--release'],
  'ios': ['build', 'ios', '--release', '--no-codesign'],
  'macos': ['build', 'macos', '--release'],
  'linux': ['build', 'linux', '--release'],
  'windows': ['build', 'windows', '--release'],
};

String _config(String platform, Iterable<String> flavors) {
  final section = _platformSection[platform]!;

  return 'flavors:\n${[for (final flavor in flavors) '  $flavor:\n    app:\n      name: "$flavor"\n'
        '    ${section.replaceAll('%s', flavor)}\n'].join()}';
}

Future<void> main(List<String> arguments) async {
  if (arguments.length != 1 || !_platforms.contains(arguments.single)) {
    stderr.writeln('Usage: dart run tool/e2e.dart <${_platforms.join('|')}>');
    exit(64);
  }

  final platform = arguments.single;
  final checkout = Directory.current;

  if (!File(p.join(checkout.path, 'pubspec.yaml')).existsSync()) {
    stderr.writeln('Run it from the root of the flutter_flavorizr checkout.');
    exit(64);
  }

  try {
    await _e2e(platform, checkout);
  } on _Failure catch (failure) {
    // Out of the `finally` of `_e2e`: the workspace is gone by now.
    stderr.writeln('e2e: ${failure.message}');
    exit(1);
  }
}

/// A step that did not do what it should.
class _Failure implements Exception {
  final String message;

  _Failure(this.message);
}

Future<void> _e2e(String platform, Directory checkout) async {
  final workspace = Directory.systemTemp.createTempSync('flavorizr_e2e_');

  try {
    final project = Directory(p.join(workspace.path, 'e2e_app'))..createSync();

    _step('flutter create');
    await _run(project, 'flutter', [
      'create',
      '--project-name=e2e_app',
      '--org=com.example',
      '--platforms=$platform',
      '.',
    ]);
    await _run(project, 'flutter', [
      'pub',
      'add',
      'dev:flutter_flavorizr',
      '--path',
      checkout.path,
    ]);

    final config = File(p.join(project.path, 'flavorizr.yaml'));

    config.writeAsStringSync(_config(platform, ['apple', 'banana']));

    _step('apply');
    await _flavorizr(project, ['apply', '--yes', '--overwrite-scaffold']);
    await _expectNothingToDo(project, 'a second run');

    _step('remove banana');
    config.writeAsStringSync(_config(platform, ['apple']));
    await _flavorizr(project, ['apply', '--yes']);
    await _expectNothingToDo(project, 'the removal of a flavor');

    final lock = File(p.join(project.path, 'flavorizr.lock'));

    if (!lock.existsSync() || lock.readAsStringSync().contains('banana')) {
      _fail('flavorizr.lock still records the flavor that was removed.');
    }

    // Before Flutter had a chance to inject its own: it is flavorizr that made
    // the pre-action.
    if (_prepareScripts.containsKey(platform)) {
      _expectOnePrepareAction(project, platform, 'apple');
    }

    _step('build apple');
    await _run(project, 'flutter', [..._build[platform]!, '--flavor', 'apple']);

    if (_prepareScripts.containsKey(platform)) {
      _expectOnePrepareAction(project, platform, 'apple');
      await _expectNothingToDo(project, 'the build');
      await _flavorizr(project, ['apply', '--yes']);
      _expectOnePrepareAction(project, platform, 'apple');
    }
  } finally {
    workspace.deleteSync(recursive: true);
  }
}

void _step(String name) => stdout.writeln('\n=== $name');

Never _fail(String message) => throw _Failure(message);

/// Runs [executable] in [directory], showing its output, and fails when it does.
Future<void> _run(
  Directory directory,
  String executable,
  List<String> arguments,
) async {
  final process = await Process.start(
    executable,
    arguments,
    workingDirectory: directory.path,
    mode: ProcessStartMode.inheritStdio,
    // `flutter` is a script on Windows.
    runInShell: Platform.isWindows,
  );
  final code = await process.exitCode;

  if (code != 0) {
    _fail('`$executable ${arguments.join(' ')}` exited with $code.');
  }
}

Future<void> _flavorizr(Directory project, List<String> arguments) =>
    _run(project, 'dart', ['run', 'flutter_flavorizr', ...arguments]);

/// The script the pre-action of Flutter runs in the schemes of each platform
/// that has them.
const _prepareScripts = {
  'ios': 'xcode_backend.sh',
  'macos': 'macos_assemble.sh',
};

/// Fails unless the scheme of [flavor] runs the prepare script of Flutter once:
/// flavorizr makes it with the pre-action, and Flutter adds none of its own
/// when it finds it.
void _expectOnePrepareAction(
  Directory project,
  String platform,
  String flavor,
) {
  final scheme = File(
    p.join(
      project.path,
      '$platform/Runner.xcodeproj/xcshareddata/xcschemes/$flavor.xcscheme',
    ),
  ).readAsStringSync();
  final count = _prepareScripts[platform]!.allMatches(scheme).length;

  if (count != 1) {
    _fail('The scheme of $flavor runs the prepare script $count times, not 1.');
  }
}

/// Fails unless `plan` reports no file to add, change or delete.
Future<void> _expectNothingToDo(Directory project, String after) async {
  final result = await Process.run(
    'dart',
    ['run', 'flutter_flavorizr', 'plan', '--json'],
    workingDirectory: project.path,
    runInShell: Platform.isWindows,
  );

  // `dart run` may print its own lines: the document is the one that is JSON.
  final line = LineSplitter.split(
    '${result.stdout}',
  ).where((line) => line.startsWith('{')).lastOrNull;

  if (result.exitCode != 0 || line == null) {
    stderr.write(result.stderr);
    _fail('`plan` failed after $after (exit code ${result.exitCode}).');
  }

  final changes = (jsonDecode(line) as Map)['changes'] as List;

  if (changes.isNotEmpty) {
    _fail(
      'plan has something to do after $after, so it is not idempotent:\n'
      '${changes.map((change) => '  $change').join('\n')}',
    );
  }
}
