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
//   dart run tool/e2e.dart <android|ios|macos|linux|windows> [--groovy]
//
// `--groovy` is for Android: the project is made a Groovy one (`build.gradle`,
// `settings.gradle`) before it is flavorized, where `flutter create` makes it a
// Kotlin one.
//
// It creates a Flutter project in a temp dir, flavorizes it with this checkout
// and checks what the user of flavorizr counts on:
//
// 1. `apply` works on a project `flutter create` made;
// 2. `plan` then has nothing to do: a second run is idempotent;
// 3. a flavor that is dropped from flavorizr.yaml is removed by `apply`, and a
//    second `plan` has nothing to do again;
// 4. the flavor that is left builds;
// 5. the build changes nothing for flavorizr, on every platform: `plan` has
//    nothing to do after it, and neither has an `apply`, which writes no file
//    of the project (a snapshot of their hashes tells). On iOS and macOS,
//    Flutter injects its Swift Package Manager pre-action into the schemes it
//    finds without one, and the scheme of the flavor has that pre-action once.
//    On Windows the build leaves `git status` clean too: the CMake file writes
//    what it configures to the binary dir, not to the source tree.
//
// On iOS the flavors have a launch screen (`launchScreen: true`), so the build
// also compiles the storyboard and the image sets flavorizr generated, and the
// files of the flavor that was dropped are gone. On iOS and macOS `apple` has an
// `icon` and `banana` a `badge` with no icon of its own, so the build compiles
// the icon sets of both, and the set of the flavor that was dropped is gone.
// The same two flavors on Windows have an `.ico` each, and the one of the flavor
// that was dropped is gone. On Android they have the launcher icons of
// `src/<flavor>/res`, with the band of the badge on those of `banana`, and the
// ones of the flavor that was dropped are gone. Linux has no icons to make.
//
// On Android `AndroidManifest.xml` has a `<meta-data>` whose value is the
// placeholder `flavorScheme` that the flavors declare: the manifest that is
// merged for the flavor that is built has the value of its own.
//
// The files of the project are the ones `flutter create` writes, so a change of
// Flutter that a processor does not follow is found here.

import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import 'e2e/checks.dart';

/// The placeholder the flavors of Android declare, and the `<meta-data>` of the
/// manifest that has it as its value.
const _placeholder = 'flavorScheme';
const _placeholderMetaData = 'e2e.flavorScheme';

const _platforms = ['android', 'ios', 'macos', 'linux', 'windows'];

/// What each flavor says about [platform].
const _platformSection = {
  // `customConfig` and `manifestPlaceholders` are rendered in Kotlin or in
  // Groovy, whichever the project is.
  'android':
      'android:\n      applicationId: "com.example.%s"'
      '\n      customConfig:\n        versionNameSuffix: "-%s"'
      '\n        matchingFallbacks: [release]'
      '\n      manifestPlaceholders:\n        $_placeholder: "scheme-%s"',
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
  // Everywhere but on Linux, which has no icons, `apple` has an icon of its own,
  // and `banana` has a badge and none: its icons are made from the one of the
  // root.
  final iconed = platform != 'linux';
  final root = [
    if (platform == 'ios') 'launchScreen: true',
    if (iconed) 'icon: assets/icon.png',
  ].map((line) => '$line\n').join();

  String flavor(String name) {
    final icon = iconed && name == 'apple'
        ? '      icon: assets/icon.png\n'
        : '';
    final badge = iconed && name == 'banana' ? '    badge: true\n' : '';

    return '  $name:\n    app:\n      name: "$name"\n$icon$badge'
        '    ${section.replaceAll('%s', name)}\n';
  }

  return '${root}flavors:\n${flavors.map(flavor).join()}';
}

Future<void> main(List<String> arguments) async {
  final groovy = arguments.contains('--groovy');
  final platforms = arguments.where((argument) => argument != '--groovy');

  if (platforms.length != 1 ||
      !_platforms.contains(platforms.single) ||
      (groovy && platforms.single != 'android')) {
    stderr.writeln(
      'Usage: dart run tool/e2e.dart <${_platforms.join('|')}> '
      '[--groovy (android only)]',
    );
    exit(64);
  }

  final platform = platforms.single;
  final checkout = Directory.current;

  if (!File(p.join(checkout.path, 'pubspec.yaml')).existsSync()) {
    stderr.writeln('Run it from the root of the flutter_flavorizr checkout.');
    exit(64);
  }

  try {
    await _e2e(platform, checkout, groovy: groovy);
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

Future<void> _e2e(
  String platform,
  Directory checkout, {
  required bool groovy,
}) async {
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

    final apple = platform == 'ios' || platform == 'macos';

    if (platform == 'android') {
      _prepareAndroid(project, groovy: groovy);
    }

    if (platform != 'linux') {
      File(p.join(project.path, 'assets/icon.png'))
        ..createSync(recursive: true)
        ..writeAsBytesSync(_icon());
    }

    _step('apply');
    await _flavorizr(project, ['apply', '--yes', '--overwrite-scaffold']);
    await _expectNothingToDo(project, 'a second run');

    if (apple) _expectIcons(project, platform, ['apple', 'banana']);
    if (platform == 'windows') _expectIcos(project, ['apple', 'banana']);
    if (platform == 'android') {
      _expectAndroidIcons(project, ['apple', 'banana']);
    }
    if (platform == 'ios') _expectLaunchScreens(project, ['apple', 'banana']);

    _step('remove banana');
    config.writeAsStringSync(_config(platform, ['apple']));
    await _flavorizr(project, ['apply', '--yes']);
    await _expectNothingToDo(project, 'the removal of a flavor');

    if (apple) {
      _expectIcons(project, platform, ['apple']);

      if (Directory(
        p.join(project.path, _assets[platform]!, 'AppIcon-banana.appiconset'),
      ).existsSync()) {
        _fail('The icons of the flavor that was removed are still there.');
      }
    }

    if (platform == 'windows') {
      _expectIcos(project, ['apple']);

      if (File(p.join(project.path, _icoOf('banana'))).existsSync()) {
        _fail('The icon of the flavor that was removed is still there.');
      }
    }

    if (platform == 'android') {
      _expectAndroidIcons(project, ['apple']);

      if (Directory(
        p.join(project.path, 'android/app/src/banana/res'),
      ).existsSync()) {
        _fail('The icons of the flavor that was removed are still there.');
      }
    }

    if (platform == 'ios') {
      _expectLaunchScreens(project, ['apple']);

      if (File(
            p.join(project.path, 'ios/Runner/bananaLaunchScreen.storyboard'),
          ).existsSync() ||
          Directory(
            p.join(
              project.path,
              'ios/Runner/Assets.xcassets/bananaLaunchImage.imageset',
            ),
          ).existsSync()) {
        _fail(
          'The launch screen of the flavor that was removed is still there.',
        );
      }
    }

    final lock = File(p.join(project.path, 'flavorizr.lock'));

    if (!lock.existsSync() || lock.readAsStringSync().contains('banana')) {
      _fail('flavorizr.lock still records the flavor that was removed.');
    }

    // Before Flutter had a chance to inject its own: it is flavorizr that made
    // the pre-action.
    if (_prepareScripts.containsKey(platform)) {
      _expectOnePrepareAction(project, platform, 'apple');
    }

    // What a build must leave as it is is what is committed, so that `git
    // status` says what it touched. The CMake file of Windows writes what it
    // configures to the binary dir: nothing is left in the source tree.
    final tracked = platform == 'windows';

    if (tracked) await _commit(project);

    _step('build apple');
    await _run(project, 'flutter', [..._build[platform]!, '--flavor', 'apple']);

    if (_prepareScripts.containsKey(platform)) {
      _expectOnePrepareAction(project, platform, 'apple');
    }

    if (tracked) await _expectCleanTree(project, 'the build');
    await _expectNothingToDo(project, 'the build');

    // `plan` says what `apply` would do, not what it did: the files of the
    // project tell it.
    final before = _snapshot(project);

    await _flavorizr(project, ['apply', '--yes']);

    final written = snapshotDiff(before, _snapshot(project));

    if (written.isNotEmpty) {
      _fail(
        'an apply after the build wrote to the project:\n'
        '${written.map((line) => '  $line').join('\n')}',
      );
    }

    await _expectNothingToDo(project, 'an apply after the build');

    if (_prepareScripts.containsKey(platform)) {
      _expectOnePrepareAction(project, platform, 'apple');
    }

    if (tracked) await _expectCleanTree(project, 'an apply after the build');
    if (platform == 'android') _expectMergedPlaceholder(project, 'apple');
  } finally {
    workspace.deleteSync(recursive: true);
  }
}

/// The asset catalog of the app, where the icon sets of the flavors are.
const _assets = {
  'ios': 'ios/Runner/Assets.xcassets',
  'macos': 'macos/Runner/Assets.xcassets',
};

/// A square icon of 1024 px, which is what the sets are made from.
List<int> _icon() => img.encodePng(
  img.Image(width: 1024, height: 1024)..clear(img.ColorRgb8(33, 150, 243)),
);

/// Fails unless each of [flavors] has the icon set of the platform, and the
/// biggest of its icons.
void _expectIcons(Directory project, String platform, List<String> flavors) {
  final biggest = platform == 'ios'
      ? 'Icon-App-1024x1024@1x.png'
      : 'app_icon_1024.png';

  for (final flavor in flavors) {
    final set = p.join(
      project.path,
      _assets[platform]!,
      'AppIcon-$flavor.appiconset',
    );

    for (final file in ['Contents.json', biggest]) {
      if (!File(p.join(set, file)).existsSync()) {
        _fail('The icons of `$flavor` have no `$file`.');
      }
    }
  }
}

/// The `.ico` of [flavor], relative to the project.
String _icoOf(String flavor) => 'windows/runner/resources/$flavor.ico';

/// Fails unless each of [flavors] has its `.ico`, and the CMake file points it
/// at it.
void _expectIcos(Directory project, List<String> flavors) {
  final cmake = File(
    p.join(project.path, 'windows/runner/CMakeLists.txt'),
  ).readAsStringSync();
  final icos = <String, List<int>>{};

  for (final flavor in flavors) {
    final ico = File(p.join(project.path, _icoOf(flavor)));

    if (!ico.existsSync()) {
      _fail('The flavor `$flavor` has no `.ico`.');
    }

    icos[flavor] = ico.readAsBytesSync();

    if (icoImageCount(icos[flavor]!) == null) {
      _fail('The `.ico` of `$flavor` is not an icon.');
    }

    if (!cmake.contains('$flavor.ico')) {
      _fail('The CMake file does not point `$flavor` at its `.ico`.');
    }
  }

  // `banana` has a badge: the same source icon with the band on it.
  if (flavors.length > 1 && _same(icos['apple']!, icos['banana']!)) {
    _fail('The `.ico` of `banana` has no badge: it is the `apple` one.');
  }
}

/// Fails unless each of [flavors] has the storyboard, the image set and the
/// `LAUNCH_SCREEN_NAME` the launch screen is made of, and `Info.plist` points
/// at it.
void _expectLaunchScreens(Directory project, List<String> flavors) {
  String read(String path) =>
      File(p.join(project.path, path)).readAsStringSync();
  bool exists(String path) => File(p.join(project.path, path)).existsSync();

  for (final flavor in flavors) {
    final files = [
      'ios/Runner/${flavor}LaunchScreen.storyboard',
      for (final name in ['', '@2x', '@3x'])
        'ios/Runner/Assets.xcassets/${flavor}LaunchImage.imageset/'
            'LaunchImage$name.png',
      'ios/Runner/Assets.xcassets/${flavor}LaunchImage.imageset/Contents.json',
    ];

    for (final file in files.where((file) => !exists(file))) {
      _fail('The launch screen of `$flavor` has no `$file`.');
    }

    for (final mode in ['Debug', 'Profile', 'Release']) {
      final xcconfig = read('ios/Flutter/$flavor$mode.xcconfig');

      if (!xcconfig.contains('LAUNCH_SCREEN_NAME=${flavor}LaunchScreen')) {
        _fail('`$flavor$mode.xcconfig` does not define LAUNCH_SCREEN_NAME.');
      }
    }
  }

  if (!read('ios/Runner/Info.plist').contains(r'$(LAUNCH_SCREEN_NAME)')) {
    _fail('Info.plist does not use LAUNCH_SCREEN_NAME.');
  }
}

/// Makes the manifest of an Android project use the placeholder the flavors
/// declare, and, with [groovy], the project a Groovy one: what `flutter create`
/// makes is a Kotlin one.
void _prepareAndroid(Directory project, {required bool groovy}) {
  File android(String path) => File(p.join(project.path, 'android', path));

  final manifest = android('app/src/main/AndroidManifest.xml');

  manifest.writeAsStringSync(
    manifestWithPlaceholder(
      manifest.readAsStringSync(),
      name: _placeholderMetaData,
      placeholder: _placeholder,
    ),
  );

  if (!groovy) return;

  try {
    android('settings.gradle').writeAsStringSync(
      groovySettings(android('settings.gradle.kts').readAsStringSync()),
    );
  } on FormatException catch (error) {
    _fail('Cannot make the project a Groovy one: ${error.message}');
  }

  android('build.gradle').writeAsStringSync(groovyRootBuild);

  try {
    android('app/build.gradle').writeAsStringSync(
      groovyAppBuild(android('app/build.gradle.kts').readAsStringSync()),
    );
  } on FormatException catch (error) {
    _fail('Cannot make the project a Groovy one: ${error.message}');
  }

  android('app/build.gradle.kts').deleteSync();
  android('settings.gradle.kts').deleteSync();
  android('build.gradle.kts').deleteSync();
}

/// The launcher icon of [flavor] for [density], relative to the project.
String _androidIconOf(String flavor, String density) =>
    'android/app/src/$flavor/res/mipmap-$density/ic_launcher.png';

/// Fails unless each of [flavors] has the launcher icon of every density, and
/// unless the icon of `banana`, which has a badge, is not the one of `apple`,
/// which has none: it is the same source icon, with the band drawn on it.
void _expectAndroidIcons(Directory project, List<String> flavors) {
  const densities = {
    'mdpi': 48,
    'hdpi': 72,
    'xhdpi': 96,
    'xxhdpi': 144,
    'xxxhdpi': 192,
  };
  final icons = <String, List<int>>{};

  for (final flavor in flavors) {
    for (final MapEntry(key: density, value: side) in densities.entries) {
      final file = File(p.join(project.path, _androidIconOf(flavor, density)));

      if (!file.existsSync()) {
        _fail('The flavor `$flavor` has no launcher icon for `$density`.');
      }

      final bytes = file.readAsBytesSync();
      final size = pngSize(bytes);

      if (size == null || size.width != side || size.height != side) {
        _fail('The launcher icon of `$flavor` for `$density` is not $side px.');
      }

      if (density == 'xxxhdpi') icons[flavor] = bytes;
    }
  }

  if (flavors.length > 1 && _same(icons['apple']!, icons['banana']!)) {
    _fail('The launcher icon of `banana` has no badge: it is the `apple` one.');
  }
}

bool _same(List<int> a, List<int> b) {
  if (a.length != b.length) return false;

  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }

  return true;
}

/// Fails unless the manifest that was merged for [flavor] has the value the
/// flavor gives to the placeholder (`scheme-<flavor>`) in the `<meta-data>`
/// that the manifest of the app has, and no other: not the placeholder as it is
/// written, nor the value of another flavor.
void _expectMergedPlaceholder(Directory project, String flavor) {
  final root = Directory(p.join(project.path, 'build/app/intermediates'));
  final merged = root.existsSync()
      ? root
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => p.basename(file.path) == 'AndroidManifest.xml')
            .where((file) => file.path.toLowerCase().contains(flavor))
            .map(
              (file) => metaDataValues(
                utf8.decode(file.readAsBytesSync(), allowMalformed: true),
                _placeholderMetaData,
              ),
            )
            .where((values) => values.isNotEmpty)
            .toList()
      : <List<String>>[];

  if (merged.isEmpty) {
    _fail('No manifest was merged for `$flavor` with `$_placeholderMetaData`.');
  }

  for (final values in merged) {
    if (values.length != 1 || values.single != 'scheme-$flavor') {
      _fail(
        'The placeholder `$_placeholder` of `$flavor` is $values in a merged '
        'manifest, not [scheme-$flavor].',
      );
    }
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

  final changes = planChanges('${result.stdout}');

  if (result.exitCode != 0 || changes == null) {
    stderr.write(result.stderr);
    _fail('`plan` failed after $after (exit code ${result.exitCode}).');
  }

  if (changes.isNotEmpty) {
    _fail(
      'plan has something to do after $after, so it is not idempotent:\n'
      '${changes.map((change) => '  $change').join('\n')}',
    );
  }
}

/// The content hash of each file of [project], by its path relative to it,
/// leaving out what a build or a tool writes (see [isBuildOutput]).
Map<String, String> _snapshot(Directory project) => {
  for (final entity in project.listSync(recursive: true, followLinks: false))
    if (entity is File &&
        !isBuildOutput(p.relative(entity.path, from: project.path)))
      p.posix.joinAll(p.split(p.relative(entity.path, from: project.path))):
          contentHash(entity.readAsBytesSync()),
};

/// Runs `git` in [project], and fails when it does.
Future<String> _git(Directory project, List<String> arguments) async {
  final result = await Process.run(
    'git',
    arguments,
    workingDirectory: project.path,
    runInShell: Platform.isWindows,
  );

  if (result.exitCode != 0) {
    stderr.write(result.stderr);
    _fail('`git ${arguments.join(' ')}` exited with ${result.exitCode}.');
  }

  return '${result.stdout}';
}

/// Commits the project as it is, with no line ending converted on the way, so
/// that `git status` tells what a build changed.
Future<void> _commit(Directory project) async {
  await _git(project, ['init', '--quiet']);
  await _git(project, ['config', 'core.autocrlf', 'false']);
  await _git(project, ['add', '--all']);
  await _git(project, [
    '-c',
    'user.name=e2e',
    '-c',
    'user.email=e2e@example.com',
    'commit',
    '--quiet',
    '--message=flavorized',
  ]);
}

/// Fails unless `git status` finds nothing changed since [_commit], and no file
/// that is new but for the ones the project ignores.
Future<void> _expectCleanTree(Directory project, String after) async {
  final dirty = dirtyPaths(await _git(project, ['status', '--porcelain']));

  if (dirty.isNotEmpty) {
    _fail(
      'git status is not clean after $after:\n'
      '${dirty.map((line) => '  $line').join('\n')}',
    );
  }
}
