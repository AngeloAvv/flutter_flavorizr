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

// The checks of `tool/e2e.dart` that are a function of a string or of bytes:
// they have no project, no Flutter and no process in them, so a test can run
// them (see test/tool_e2e_checks_test.dart).

import 'dart:convert';

import 'package:crypto/crypto.dart';

/// The `changes` of the document that `flavorizr plan --json` printed on
/// [stdout], or `null` when there is no such document.
///
/// `dart run` may print its own lines before it: the document is the last one
/// that is JSON.
List<Object?>? planChanges(String stdout) {
  final line = LineSplitter.split(
    stdout,
  ).where((line) => line.startsWith('{')).lastOrNull;

  if (line == null) {
    return null;
  }

  final document = jsonDecode(line);

  return document is Map && document['changes'] is List
      ? (document['changes'] as List).cast<Object?>()
      : null;
}

/// The lines of `git status --porcelain` ([porcelain]): one for each path that
/// is changed, added, deleted or untracked. None when the tree is clean.
List<String> dirtyPaths(String porcelain) => LineSplitter.split(
  porcelain,
).map((line) => line.trimRight()).where((line) => line.isNotEmpty).toList();

/// The folders that a build, a `pub get` or the version control fill, and which
/// are not the sources of the project: a snapshot does not look below them.
const _outputFolders = {
  'build',
  '.dart_tool',
  '.git',
  '.gradle',
  '.symlinks',
  'Pods',
  'ephemeral',
  'DerivedData',
};

/// Whether [relativePath] (of the project, `/` or `\` separated) is the output
/// of a build or a tool, which a snapshot of the sources leaves out.
bool isBuildOutput(String relativePath) =>
    relativePath.split(RegExp(r'[/\\]')).any(_outputFolders.contains);

/// The hash of the content of a file, which a snapshot keeps in place of it.
String contentHash(List<int> bytes) => sha256.convert(bytes).toString();

/// What differs between two snapshots of a project, each a map of the path of a
/// file to the [contentHash] of its content: the files that were added, removed
/// or changed, one line each and in the order of the paths. None when [after] is
/// [before].
List<String> snapshotDiff(
  Map<String, String> before,
  Map<String, String> after,
) {
  final paths = {...before.keys, ...after.keys}.toList()..sort();

  return [
    for (final path in paths)
      if (!before.containsKey(path))
        'added $path'
      else if (!after.containsKey(path))
        'removed $path'
      else if (before[path] != after[path])
        'changed $path',
  ];
}

/// Whether [bytes] start with the signature of a PNG and hold its `IHDR`.
bool isPng(List<int> bytes) {
  const signature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

  if (bytes.length < 24) {
    return false;
  }

  for (var i = 0; i < signature.length; i++) {
    if (bytes[i] != signature[i]) {
      return false;
    }
  }

  return true;
}

/// The size of the PNG [bytes], read from its `IHDR` chunk, or `null` when they
/// are not a PNG.
({int width, int height})? pngSize(List<int> bytes) {
  if (!isPng(bytes)) {
    return null;
  }

  int word(int offset) =>
      (bytes[offset] << 24) |
      (bytes[offset + 1] << 16) |
      (bytes[offset + 2] << 8) |
      bytes[offset + 3];

  return (width: word(16), height: word(20));
}

/// How many images the ICO [bytes] hold, or `null` when they are not an ICO (a
/// reserved word of 0, the type 1, then the count, which is at least 1).
int? icoImageCount(List<int> bytes) {
  if (bytes.length < 6 ||
      bytes[0] != 0 ||
      bytes[1] != 0 ||
      bytes[2] != 1 ||
      bytes[3] != 0) {
    return null;
  }

  final count = bytes[4] | (bytes[5] << 8);

  return count > 0 ? count : null;
}

/// [manifest] with a `<meta-data>` named [name], whose value is the placeholder
/// [placeholder] (`${placeholder}`), just before `</application>`.
///
/// Throws a [FormatException] when [manifest] has no `application`.
String manifestWithPlaceholder(
  String manifest, {
  required String name,
  required String placeholder,
}) {
  const closing = '</application>';
  final at = manifest.lastIndexOf(closing);

  if (at < 0) {
    throw const FormatException('The manifest has no <application>.');
  }

  return '${manifest.substring(0, at)}'
      '    <meta-data android:name="$name" '
      'android:value="\${$placeholder}" />\n    '
      '${manifest.substring(at)}';
}

/// The `android:value` of every `<meta-data>` of [manifest] named [name], in the
/// order they are in. The attributes may come in any order, on any lines.
List<String> metaDataValues(String manifest, String name) {
  final values = <String>[];

  for (final tag in RegExp(
    r'<meta-data\b[^>]*>',
    dotAll: true,
  ).allMatches(manifest)) {
    String? attribute(String key) => RegExp(
      '\\b${RegExp.escape(key)}\\s*=\\s*"([^"]*)"',
    ).firstMatch(tag.group(0)!)?.group(1);

    final value = attribute('android:value');

    if (attribute('android:name') == name && value != null) {
      values.add(value);
    }
  }

  return values;
}

/// The `android/settings.gradle` of a Groovy project with the plugins that
/// [kotlinSettings], the `android/settings.gradle.kts` `flutter create` makes,
/// has.
///
/// Flutter picks the versions of the Android and Kotlin plugins, so they are the
/// ones that are kept: only the syntax changes. Throws a [FormatException] when
/// [kotlinSettings] has no `plugins` block, which is what a change of Flutter
/// that this does not follow looks like.
String groovySettings(String kotlinSettings) {
  final start = kotlinSettings.indexOf(RegExp(r'^plugins \{', multiLine: true));

  if (start < 0) {
    throw const FormatException('settings.gradle.kts has no plugins block.');
  }

  final plugins = kotlinSettings
      .substring(start)
      .replaceAllMapped(
        RegExp(r'\bid\("([^"]+)"\)'),
        (match) => 'id "${match.group(1)}"',
      )
      .replaceAllMapped(
        RegExp(r'\binclude\("([^"]+)"\)'),
        (match) => 'include "${match.group(1)}"',
      );

  return '''
pluginManagement {
    def flutterSdkPath = {
        def properties = new Properties()
        file("local.properties").withInputStream { properties.load(it) }
        def flutterSdkPath = properties.getProperty("flutter.sdk")
        assert flutterSdkPath != null, "flutter.sdk not set in local.properties"
        return flutterSdkPath
    }()

    includeBuild("\$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

$plugins''';
}

/// The `android/app/build.gradle` of a Groovy project, from [kotlinBuild], the
/// `android/app/build.gradle.kts` `flutter create` makes: valid Groovy as it is
/// (calls and assignments only), but for `buildFeatures.resValues`.
///
/// The Groovy `flavorizr.gradle` declares a `resValue` for each flavor (the
/// `app_name`) and, unlike the Kotlin one, does not enable the feature, which
/// the Android Gradle Plugin has off by default: the project turns it on, as
/// the Kotlin one is turned on by flavorizr.
///
/// Throws a [FormatException] when [kotlinBuild] has no `android` block.
String groovyAppBuild(String kotlinBuild) {
  final android = RegExp(
    r'^android \{\n',
    multiLine: true,
  ).firstMatch(kotlinBuild);

  if (android == null) {
    throw const FormatException('build.gradle.kts has no android block.');
  }

  return '${kotlinBuild.substring(0, android.end)}'
      '    buildFeatures {\n'
      '        resValues = true\n'
      '    }\n'
      '\n'
      '${kotlinBuild.substring(android.end)}';
}

/// The `android/build.gradle` of a Groovy project, which `flutter create` makes
/// as `build.gradle.kts`.
const groovyRootBuild = '''
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.layout.buildDirectory.value(
    rootProject.layout.buildDirectory.dir("../../build").get())

subprojects {
    project.layout.buildDirectory.value(
        rootProject.layout.buildDirectory.dir(project.name).get())
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register("clean", Delete) {
    delete rootProject.layout.buildDirectory
}
''';
