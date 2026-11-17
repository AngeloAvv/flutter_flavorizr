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

import 'dart:io';

import 'package:flutter_flavorizr/src/engine/artifact.dart';
import 'package:flutter_flavorizr/src/engine/flavorizr_context.dart';
import 'package:flutter_flavorizr/src/engine/flavorizr_processor.dart';
import 'package:flutter_flavorizr/src/engine/processors/darwin/xcconfig_references.dart';
import 'package:flutter_flavorizr/src/engine/processors/darwin/xcconfig_sources.dart';
import 'package:flutter_flavorizr/src/engine/resource_key.dart';
import 'package:flutter_flavorizr/src/engine/resources/xcodeproj_resource.dart';
import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:flutter_flavorizr/src/parser/models/flavors/darwin/enums.dart';
import 'package:flutter_flavorizr/src/parser/models/flavors/flavor.dart';
import 'package:flutter_flavorizr/src/utils/constants.dart';
import 'package:path/path.dart' as p;

/// Writes the `.xcconfig` of every flavor and build mode (`debug`, `profile`
/// and `release`) of a platform, in [folder].
///
/// Every file is [Artifact.managed]: it is generated whole from the
/// configuration and written **as text**, so it is hashed in the lock, a hand
/// edit of it is a conflict, and the files of a flavor that was dropped are
/// cleaned by the reconciliation of stale artifacts. Nothing reads an xcconfig
/// back and writes it again, which is what loses `#include?` (it becomes
/// `#include`, and the build breaks until `pod install` ran), the comments and
/// the order of the file.
///
/// Everything is rendered, and the flavor names checked, before the first file
/// is written.
abstract class _XcconfigProcessor extends FlavorizrProcessor {
  const _XcconfigProcessor();

  /// Where the files go, relative to the project.
  String get folder;

  /// The flavors of the platform.
  Map<String, Flavor> flavors(Flavorizr config);

  /// The text of the file of [flavorName] for [target].
  String render(
    Flavorizr config,
    String flavorName,
    Flavor flavor,
    Target target,
  );

  /// Writes the files, and returns the paths of the ones that were written,
  /// relative to the project.
  Future<List<String>> writeXcconfigs(FlavorizrContext ctx) async {
    final sources = <String, String>{};

    for (final MapEntry(key: flavorName, value: flavor) in flavors(
      ctx.config,
    ).entries) {
      _checkFlavorName(flavorName);

      for (final target in Target.values) {
        sources[p.posix.join(folder, xcconfigName(flavorName, target))] =
            render(ctx.config, flavorName, flavor, target);
      }
    }

    for (final MapEntry(key: path, value: source) in sources.entries) {
      ctx.logger.detail('[$id] Writing `$path`');

      final file = File(ctx.resolve(path));

      await file.parent.create(recursive: true);
      await file.writeAsString(source);
      ctx.track(Artifact.managed(path));
    }

    return sources.keys.toList(growable: false);
  }

  /// A flavor name becomes part of a file name, so it must be a single path
  /// segment: `../Runner` or `a/b` would write somewhere else in the project.
  static void _checkFlavorName(String flavor) {
    if (flavor.isEmpty ||
        flavor == '.' ||
        flavor == '..' ||
        flavor.contains(RegExp(r'[/\\\x00]'))) {
      throw ArgumentError.value(
        flavor,
        'flavor',
        'cannot be used as the name of a file',
      );
    }
  }
}

/// `ios:xcconfig`: the xcconfig files of the iOS flavors, in `ios/Flutter`,
/// and their references in the project.
///
/// The references are in the group `Flutter` of `Runner.xcodeproj`, which they
/// share with the ones of Flutter. They are never in a build phase: the
/// xcconfigs are the base configuration of the build configurations (which
/// `ios:buildTargets` points at them), not resources, and 2.x copying them
/// into the app bundle was a bug. Whatever a 2.x run left in the Resources
/// phase is taken out, whatever the flavor. See [addXcconfigReference] and
/// [removeXcconfigsFromResources].
///
/// The project is the shared `xcodeproj:ios`: it is not opened or saved here,
/// and the processor tracks it, as a patched artifact.
class IosXcconfigProcessor extends _XcconfigProcessor {
  /// Creates the processor.
  const IosXcconfigProcessor();

  @override
  String get id => 'ios:xcconfig';

  @override
  Set<ResourceKey<Object?>> get requires => {XcodeprojResource.iosKey};

  @override
  String get folder => K.iOSFlutterPath;

  @override
  Map<String, Flavor> flavors(Flavorizr config) => config.iosFlavors;

  @override
  String render(
    Flavorizr config,
    String flavorName,
    Flavor flavor,
    Target target,
  ) => iosXcconfigSource(config, flavorName, flavor, target);

  @override
  Future<void> apply(FlavorizrContext ctx) async {
    final paths = await writeXcconfigs(ctx);
    final project = ctx.resource(XcodeprojResource.iosKey);

    for (final path in paths) {
      addXcconfigReference(
        project,
        p.posix.relative(path, from: K.iOSPath),
        groupName: 'Flutter',
      );
    }
    removeXcconfigsFromResources(project);

    ctx.track(XcodeprojResource.iosArtifact);
  }
}

/// `macos:xcconfig`: the xcconfig files of the macOS flavors that Flutter owns,
/// in `macos/Flutter`.
///
/// They are text only: nothing references them in the project, which includes
/// them from the files of `macos:configs`.
class MacosXcconfigProcessor extends _XcconfigProcessor {
  /// Creates the processor.
  const MacosXcconfigProcessor();

  @override
  String get id => 'macos:xcconfig';

  @override
  String get folder => K.macOSFlutterPath;

  @override
  Map<String, Flavor> flavors(Flavorizr config) => config.macosFlavors;

  @override
  String render(
    Flavorizr config,
    String flavorName,
    Flavor flavor,
    Target target,
  ) => macosFlutterXcconfigSource(config, flavorName, flavor, target);

  @override
  Future<void> apply(FlavorizrContext ctx) async {
    await writeXcconfigs(ctx);
  }
}

/// `macos:configs`: the xcconfig files of the macOS flavors that the project
/// builds with, in `macos/Runner/Configs`, which include the ones of
/// `macos:xcconfig`, and their references in the project.
///
/// The references are in the main group, and never in a build phase, like the
/// ones of [IosXcconfigProcessor].
class MacosConfigsProcessor extends _XcconfigProcessor {
  /// Creates the processor.
  const MacosConfigsProcessor();

  @override
  String get id => 'macos:configs';

  @override
  Set<String> get after => const {'macos:xcconfig'};

  @override
  Set<ResourceKey<Object?>> get requires => {XcodeprojResource.macosKey};

  @override
  String get folder => K.macOSConfigsPath;

  @override
  Map<String, Flavor> flavors(Flavorizr config) => config.macosFlavors;

  @override
  String render(
    Flavorizr config,
    String flavorName,
    Flavor flavor,
    Target target,
  ) => macosConfigsXcconfigSource(config, flavorName, flavor, target);

  @override
  Future<void> apply(FlavorizrContext ctx) async {
    final paths = await writeXcconfigs(ctx);
    final project = ctx.resource(XcodeprojResource.macosKey);

    for (final path in paths) {
      addXcconfigReference(project, p.posix.relative(path, from: K.macOSPath));
    }
    removeXcconfigsFromResources(project);

    ctx.track(XcodeprojResource.macosArtifact);
  }
}
