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
import 'package:flutter_flavorizr/src/engine/resource_key.dart';
import 'package:flutter_flavorizr/src/engine/resources/xcodeproj_resource.dart';
import 'package:flutter_flavorizr/src/exception/file_not_found_exception.dart';
import 'package:flutter_flavorizr/src/exception/malformed_resource_exception.dart';
import 'package:flutter_flavorizr/src/parser/models/flavors/flavor.dart';
import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:flutter_flavorizr/src/processors/darwin/darwin_add_file_processor.dart';
import 'package:flutter_flavorizr/src/utils/constants.dart';
import 'package:flutter_flavorizr/src/utils/darwin_utils.dart';
import 'package:path/path.dart' as p;

/// The name Xcode shows for the build phase that copies the Firebase
/// configuration of the flavor that is built.
const firebaseBuildPhaseName = 'Firebase Setup';

/// What [ctx] copies of the Firebase configuration of a flavor: the file at
/// [source], a path of the project, to [destination], below the workspace.
///
/// The source is an input of the user, read from the real project and kept inside
/// it, links included. The copy is [Artifact.local]: the IDEs and the builds
/// work with it, so it is written again silently on every run, never hashed in
/// the lock, and never a conflict or drift.
Future<void> _copyConfig(
  FlavorizrContext ctx,
  String source,
  String destination,
) async {
  final resolved = ctx.resolveProject(source);

  switch (FileSystemEntity.typeSync(resolved)) {
    case FileSystemEntityType.notFound:
      throw FileNotFoundException(source);
    case FileSystemEntityType.file:
      break;
    default:
      throw MalformedResourceException(source);
  }

  // `resolve` is lexical: a link inside the project may still lead out of it.
  final real = await File(resolved).resolveSymbolicLinks();
  final realProject = await ctx.projectRoot.resolveSymbolicLinks();

  if (!p.isWithin(realProject, real)) {
    throw ArgumentError.value(
      source,
      'firebase.config',
      'must stay within `${ctx.projectRoot.path}`, links included',
    );
  }

  final target = File(ctx.resolve(destination));

  await target.parent.create(recursive: true);
  await File(real).copy(target.path);
  ctx.track(Artifact.local(destination));
}

/// `android:firebase`: the `google-services.json` of each Android flavor that
/// has a Firebase configuration, in `android/app/src/<flavor>`, where the Google
/// services plugin looks for the one of the flavor that is built.
class AndroidFirebaseProcessor extends FlavorizrProcessor {
  /// Creates the processor.
  const AndroidFirebaseProcessor();

  @override
  String get id => 'android:firebase';

  @override
  Future<void> apply(FlavorizrContext ctx) async {
    for (final MapEntry(key: flavor, value: definition)
        in ctx.config.androidFirebaseFlavors.entries) {
      _checkFlavorName(flavor);

      await _copyConfig(
        ctx,
        definition.android!.firebase!.config,
        '${K.androidSrcPath}/$flavor/google-services.json',
      );
    }
  }
}

/// The script of the build phase: it copies the configuration of the flavor
/// that is built to `Runner/GoogleService-Info.plist`.
///
/// The configuration is told by the name of the build configuration, which is
/// `Debug-<flavor>`, `Profile-<flavor>` or `Release-<flavor>`.
String firebaseScriptSource(Iterable<String> flavors) {
  final buffer = StringBuffer();
  var keyword = 'if';

  for (final flavor in flavors) {
    buffer
      ..writeln(
        '$keyword [ "\$CONFIGURATION" == "Debug-$flavor" ] || '
        '[ "\$CONFIGURATION" == "Release-$flavor" ]; then',
      )
      ..writeln(
        '  cp Runner/$flavor/GoogleService-Info.plist '
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
///   [Artifact.local].
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
  Map<String, String> sources(Flavorizr config);

  @override
  Set<ResourceKey<Object?>> get requires => {projectKey};

  @override
  Future<void> apply(FlavorizrContext ctx) async {
    final flavors = sources(ctx.config);
    final owned = this.owned(ctx);

    for (final MapEntry(key: flavor, value: source) in flavors.entries) {
      _checkFlavorName(flavor);

      await _copyConfig(
        ctx,
        source,
        '$runnerPath/$flavor/GoogleService-Info.plist',
      );
    }

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

  void _ensureFileReference(XcodeProject project) =>
      DarwinAddFileProcessor.addTo(
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
  Map<String, String> sources(Flavorizr config) => {
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
  Map<String, String> sources(Flavorizr config) => {
    for (final MapEntry(key: flavor, value: Flavor(:macos))
        in config.macosFirebaseFlavors.entries)
      flavor: macos!.firebase!.config,
  };
}

void _checkFlavorName(String flavor) {
  if (flavor.isEmpty ||
      flavor == '.' ||
      flavor == '..' ||
      flavor.contains(RegExp(r'[/\\\x00]'))) {
    throw ArgumentError.value(
      flavor,
      'flavor',
      'cannot be used as the name of a directory',
    );
  }
}
