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

import 'package:dart_xcodeproj/dart_xcodeproj.dart';
import 'package:flutter_flavorizr/src/engine/artifact.dart';
import 'package:flutter_flavorizr/src/engine/darwin/owned_objects.dart';
import 'package:flutter_flavorizr/src/engine/darwin/pbxproj_seed.dart';
import 'package:flutter_flavorizr/src/engine/flavorizr_context.dart';
import 'package:flutter_flavorizr/src/engine/flavorizr_processor.dart';
import 'package:flutter_flavorizr/src/engine/processors/project_config_copy.dart';
import 'package:flutter_flavorizr/src/engine/resource_key.dart';
import 'package:flutter_flavorizr/src/engine/resources/xcodeproj_file_reference.dart';
import 'package:flutter_flavorizr/src/engine/resources/xcodeproj_resource.dart';
import 'package:flutter_flavorizr/src/parser/models/flavors/flavor.dart';
import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:flutter_flavorizr/src/utils/constants.dart';
import 'package:flutter_flavorizr/src/utils/darwin_utils.dart';

/// The name Xcode shows for the build phase that copies the Firebase
/// configuration of the flavor that is built.
const firebaseBuildPhaseName = 'Firebase Setup';

Future<void> _copyConfig(
  FlavorizrContext ctx,
  String source,
  String destination,
) => copyProjectConfig(
  ctx,
  source: source,
  destination: destination,
  option: 'firebase.config',
);

/// The name of the copy of the Firebase configuration of an Android flavor.
const androidFirebaseFile = 'google-services.json';

/// The name of the copy of the Firebase configuration of an Apple flavor.
const appleFirebaseFile = 'GoogleService-Info.plist';

/// `android:firebase`: the `google-services.json` of each Android flavor that
/// has a Firebase configuration, in `android/app/src/<flavor>`, where the Google
/// services plugin looks for the one of the flavor that is built.
///
/// A flavor that loses its configuration, or that is removed, loses the copy
/// flavorizr made for it, as long as it still holds what flavorizr copied: see
/// [removeStaleCopies].
class AndroidFirebaseProcessor extends FlavorizrProcessor {
  /// Creates the processor.
  const AndroidFirebaseProcessor();

  @override
  String get id => 'android:firebase';

  @override
  Future<void> apply(FlavorizrContext ctx) async {
    final copies = <String>{};

    for (final MapEntry(key: flavor, value: definition)
        in ctx.config.androidFirebaseFlavors.entries) {
      checkFlavorName(flavor);

      final destination = '${K.androidSrcPath}/$flavor/$androidFirebaseFile';

      await _copyConfig(ctx, definition.android!.firebase!.config, destination);
      copies.add(destination);
    }

    removeStaleCopies(
      ctx,
      keep: copies,
      isCopy: (path) => isFlavorCopyPath(
        path,
        parent: K.androidSrcPath,
        name: androidFirebaseFile,
      ),
    );
  }
}

/// The script of the build phase: it copies the configuration of the flavor
/// that is built to `Runner/GoogleService-Info.plist`.
///
/// The configuration is told by the name of the build configuration, which is
/// `Debug-<flavor>`, `Profile-<flavor>` or `Release-<flavor>` (2.x left the
/// Profile ones out, which kept whatever configuration was there). A name that
/// is not made of letters, digits, `_`, `.` and `-` is quoted for the shell.
String firebaseScriptSource(Iterable<String> flavors) {
  final buffer = StringBuffer();
  var keyword = 'if';

  for (final flavor in flavors) {
    final conditions = [
      for (final mode in const ['Debug', 'Profile', 'Release'])
        '[ "\$CONFIGURATION" == ${_shellLiteral('$mode-$flavor')} ]',
    ];

    buffer
      ..writeln('$keyword ${conditions.join(' || ')}; then')
      ..writeln(
        '  cp ${_shellWord('Runner/$flavor/GoogleService-Info.plist')} '
        'Runner/GoogleService-Info.plist',
      );
    keyword = 'elif';
  }

  if (keyword == 'elif') {
    buffer
      ..writeln('fi')
      ..writeln();
  }

  return buffer.toString();
}

final _plain = RegExp(r'^[A-Za-z0-9_./-]+$');

/// [value] as a word of the shell: as it is when it needs no quoting.
String _shellWord(String value) =>
    _plain.hasMatch(value) ? value : "'${value.replaceAll("'", r"'\''")}'";

/// [value] as a string to compare with: in double quotes when it needs no
/// quoting, as 2.x did.
String _shellLiteral(String value) =>
    _plain.hasMatch(value) ? '"$value"' : _shellWord(value);

/// The UUID of the build phase of [platform], which is the same on every run
/// and in every project: it is how the lock, and the owned content of the
/// project, tell the phase flavorizr made from the ones of the user.
String firebaseBuildPhaseUuid(String platform) =>
    PbxprojSeed.uuid(platform: platform, kind: const ['firebaseBuildPhase']);

final _definition = RegExp(
  r'^(\s*)([0-9A-F]{24}(?:[0-9A-F]{8})?)(?: /\*.*?\*/)? = \{\s*$',
);
final _listing = RegExp(
  r'^\s*([0-9A-F]{24}(?:[0-9A-F]{8})?)(?: /\*.*?\*/)?,\s*$',
);

/// The part of a `project.pbxproj` the build phase of [platform] makes up: its
/// definition, which is a block of lines, and the line that lists it in the
/// phases of the target. It is what the lock hashes for it, so that whatever
/// else Xcode, CocoaPods and the user write in the project is never drift, and
/// a change of the phase alone is written back.
String firebaseOwnedContent(String source, String platform) {
  final uuid = firebaseBuildPhaseUuid(platform);
  final lines = source.split(RegExp(r'\r?\n'));
  final owned = <String>[];
  String? closing;

  for (final line in lines) {
    if (closing != null) {
      owned.add(line);

      if (line == closing) closing = null;

      continue;
    }

    final definition = _definition.firstMatch(line);

    if (definition != null && definition.group(2) == uuid) {
      owned.add(line);
      closing = '${definition.group(1)}};';

      continue;
    }

    if (_listing.firstMatch(line)?.group(1) == uuid) owned.add(line);
  }

  return owned.join('\n');
}

/// The base of `ios:firebase` and `macos:firebase`: the Firebase configuration
/// of the flavors of an Apple platform, and the build phase that copies the one
/// of the flavor that is built to `Runner/GoogleService-Info.plist`.
///
/// * `<platform>/Runner/<flavor>/GoogleService-Info.plist` is the copy of each
///   flavor, and `<platform>/Runner/GoogleService-Info.plist` an empty file when
///   the project has none: the build overwrites it, so both are
///   [Artifact.local]. The copy of a flavor that loses its configuration, or
///   that is removed, goes with it, as long as it still holds what flavorizr
///   copied (see [removeStaleCopies]). The empty file is not a copy of any
///   flavor, and stays.
/// * `<platform>/firebaseScript.sh` is generated whole from the flavors, so it
///   is [Artifact.managed]: a flavor that loses its configuration is out of it,
///   and the script goes when none is left.
/// * The build phase is **owned** (`OwnedObjects`): it has a UUID of its own,
///   the same on every run, so a run finds it and updates it in place instead
///   of making another, the project does not change when nothing does, and
///   the phase of a platform that lost its configuration is removed by UUID. A
///   phase of the same name that 2.x made, with a random one, is replaced by it.
///
/// The project is the shared one of the run, and the processor tracks it, as a
/// patched artifact.
abstract class _AppleFirebaseProcessor extends FlavorizrProcessor {
  const _AppleFirebaseProcessor();

  /// `ios` or `macos`.
  String get platform;

  /// The folder of the app, `ios/Runner` or `macos/Runner`.
  String get runnerPath;

  /// The script of the build phase, `ios/firebaseScript.sh`.
  String get scriptPath;

  ResourceKey<XcodeProject> get projectKey;

  Artifact get projectArtifact;

  OwnedObjects owned(FlavorizrContext ctx);

  /// The flavors that have a Firebase configuration, with where it is.
  Map<String, String> sources(FlavorizrConfig config);

  @override
  Set<ResourceKey<Object?>> get requires => {projectKey};

  @override
  Future<void> apply(FlavorizrContext ctx) async {
    final flavors = sources(ctx.config);
    final owned = this.owned(ctx);
    final copies = <String>{};

    for (final MapEntry(key: flavor, value: source) in flavors.entries) {
      checkFlavorName(flavor);

      final destination = '$runnerPath/$flavor/$appleFirebaseFile';

      await _copyConfig(ctx, source, destination);
      copies.add(destination);
    }

    removeStaleCopies(
      ctx,
      keep: copies,
      isCopy: (path) =>
          isFlavorCopyPath(path, parent: runnerPath, name: appleFirebaseFile),
    );

    // Without a configuration the processor makes nothing, and `settle` takes
    // out what an earlier run made: the phase of 2.x, which no lock names, is
    // not flavorizr's to remove.
    if (flavors.isNotEmpty) {
      await _placeholder(ctx);

      final script = firebaseScriptSource(flavors.keys);
      final scriptFile = File(ctx.resolve(scriptPath));

      await scriptFile.parent.create(recursive: true);
      await scriptFile.writeAsString(script);
      ctx.track(Artifact.managed(scriptPath));

      _ensureFileReference(owned.project);
      _ensurePhase(owned, script);
    }

    owned.settle();

    ctx.track(projectArtifact);
  }

  /// `Runner/GoogleService-Info.plist`, which the phase writes to: an empty file
  /// when there is none, so that the project can name it.
  Future<void> _placeholder(FlavorizrContext ctx) async {
    final path = '$runnerPath/GoogleService-Info.plist';

    if (File(ctx.resolveProject(path)).existsSync()) return;

    final file = File(ctx.resolve(path));

    await file.parent.create(recursive: true);
    await file.writeAsString('');
    ctx.track(Artifact.local(path));
  }

  void _ensureFileReference(XcodeProject project) => addFileToProject(
    project,
    flatPath('$runnerPath/GoogleService-Info.plist'),
  );

  PBXNativeTarget _runner(XcodeProject project) =>
      project.targets.first as PBXNativeTarget;

  /// Takes out the phases of the name of ours that have another UUID: the ones
  /// 2.x made, which it made again on every run.
  void _removeStalePhases(XcodeProject project, {required String keep}) {
    final target = _runner(project);

    for (final phase in target.shellScriptBuildPhases.toList()) {
      if (phase.name == firebaseBuildPhaseName && phase.uuid != keep) {
        target.buildPhases.remove(phase);
        phase.removeFromProject();
      }
    }
  }

  void _ensurePhase(OwnedObjects owned, String script) {
    final project = owned.project;
    final target = _runner(project);
    final uuid = firebaseBuildPhaseUuid(platform);

    _removeStalePhases(project, keep: uuid);

    final phase = owned.ensure<PBXShellScriptBuildPhase>(
      (project, uuid) => PBXShellScriptBuildPhase(project, uuid),
      kind: const ['firebaseBuildPhase'],
      create: (phase) => target.buildPhases.add(phase),
    );

    phase
      ..name = firebaseBuildPhaseName
      ..shellScript = script
      ..outputPaths = [r'$(SRCROOT)/Runner/GoogleService-Info.plist'];

    // It has to run before the build phases that need the file.
    if (!identical(target.buildPhases.firstOrNull, phase)) {
      target.buildPhases.move(phase, 0);
    }
  }
}

/// `ios:firebase`. See [_AppleFirebaseProcessor].
class IosFirebaseProcessor extends _AppleFirebaseProcessor {
  /// Creates the processor.
  const IosFirebaseProcessor();

  @override
  String get id => 'ios:firebase';

  @override
  String get platform => 'ios';

  @override
  String get runnerPath => K.iOSRunnerPath;

  @override
  String get scriptPath => K.iOSFirebaseScriptPath;

  @override
  ResourceKey<XcodeProject> get projectKey => XcodeprojResource.iosKey;

  @override
  Artifact get projectArtifact => XcodeprojResource.iosArtifact;

  @override
  OwnedObjects owned(FlavorizrContext ctx) => OwnedObjects.ios(ctx);

  @override
  Map<String, String> sources(FlavorizrConfig config) => {
    for (final MapEntry(key: flavor, value: Flavor(:ios))
        in config.iosFirebaseFlavors.entries)
      flavor: ios!.firebase!.config,
  };
}

/// `macos:firebase`. See [_AppleFirebaseProcessor].
class MacosFirebaseProcessor extends _AppleFirebaseProcessor {
  /// Creates the processor.
  const MacosFirebaseProcessor();

  @override
  String get id => 'macos:firebase';

  @override
  String get platform => 'macos';

  @override
  String get runnerPath => K.macOSRunnerPath;

  @override
  String get scriptPath => K.macOSFirebaseScriptPath;

  @override
  ResourceKey<XcodeProject> get projectKey => XcodeprojResource.macosKey;

  @override
  Artifact get projectArtifact => XcodeprojResource.macosArtifact;

  @override
  OwnedObjects owned(FlavorizrContext ctx) => OwnedObjects.macos(ctx);

  @override
  Map<String, String> sources(FlavorizrConfig config) => {
    for (final MapEntry(key: flavor, value: Flavor(:macos))
        in config.macosFirebaseFlavors.entries)
      flavor: macos!.firebase!.config,
  };
}
