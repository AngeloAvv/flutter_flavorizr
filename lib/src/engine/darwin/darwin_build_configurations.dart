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

import 'package:dart_xcodeproj/dart_xcodeproj.dart';
import 'package:flutter_flavorizr/src/engine/darwin/owned_build_settings.dart';
import 'package:flutter_flavorizr/src/engine/darwin/owned_objects.dart';

/// The build configurations of a flavor in an Xcode project, made through
/// [OwnedObjects]: what the 2.x `DarwinAddBuildConfigurationProcessor` did on its own
/// with random UUIDs, now deterministic, found again on every run and removable.
///
/// For each mode of the flavor (`Debug`, `Profile`, `Release`) it makes:
///
/// * the configuration `<Mode>-<flavor>` of the project, with the settings of
///   the project `<Mode>` configuration and then the ones of the flavor;
/// * the configuration `<Mode>-<flavor>` of the first native target, with
///   `PRODUCT_NAME`;
/// * the reference to the xcconfig file of the mode, in the main group, unless
///   the project has one at that path already (`ios:xcconfig` makes it, in the
///   group of Flutter). It is identified by its path, so flavors that share a
///   file share the reference. It is **not** put in the resources of the target:
///   an xcconfig is the base configuration of the configurations below, never a
///   resource, which 2.x got wrong and copied the files into the app bundle.
///
/// Both configurations point to the xcconfig file as their base configuration.
/// Everything is owned but the objects that existed (a `Debug-dev` made by 2.x,
/// the file reference of the xcconfig that `ios:xcconfig` added): they are used
/// as they are, keeping their UUIDs, and never removed.
///
/// A configuration that exists is **not** rewritten, and neither is a setting
/// that flavorizr does not own: the settings it sets are edited **key by key**
/// through [OwnedBuildSettings] (#515), so the `DEVELOPMENT_TEAM` of the user
/// survives a run. Without [OwnedBuildSettings] a configuration that exists is
/// left as it is. Its base configuration is only filled in when it has none.
/// A flavor that is no longer wanted is not handled here either: its objects
/// are removed by [OwnedObjects.settle], which the processor calls at the end.
abstract final class DarwinBuildConfigurations {
  /// The modes of every flavor, as they are spelled in the names of the
  /// configurations and of the xcconfig files.
  static const modes = ['Debug', 'Profile', 'Release'];

  /// What flavorizr sets in the configurations of the target.
  static const _targetSettings = {'PRODUCT_NAME': r'$(TARGET_NAME)'};

  /// Makes the build configurations of [flavor].
  ///
  /// [buildSettings] are the settings of the flavor (the ones of the
  /// application, then the ones of the flavor), and [xcconfigPath] tells where
  /// the xcconfig file of a mode is, as the file reference of the project spells
  /// it (`Flutter/devDebug.xcconfig`).
  ///
  /// The objects of the project that are there already are used as they are and
  /// not owned, unless [claimExisting] is set: it is for a project 2.x
  /// flavorized, whose objects flavorizr made and may remove with the flavor.
  ///
  /// With [settings], the settings of [buildSettings] (and `PRODUCT_NAME` of
  /// the target) are set **key by key** on the configurations, the ones that
  /// exist included, and owned: the caller ends the run with
  /// [OwnedBuildSettings.settle].
  ///
  /// Throws a [StateError], before it changes anything, when the project has no
  /// native target, or a target without a name or build configurations.
  static void ensure(
    OwnedObjects owned, {
    required String flavor,
    Map<String, dynamic> buildSettings = const {},
    required String Function(String mode) xcconfigPath,
    bool claimExisting = false,
    OwnedBuildSettings? settings,
  }) {
    final project = owned.project;
    final target = project.nativeTargets.firstOrNull;
    final targetName = target?.name;
    final targetList = target?.buildConfigurationList;

    if (target == null || targetName == null || targetList == null) {
      throw StateError(
        'The project has no native target with a name and build '
        'configurations to add the configurations of `$flavor` to.',
      );
    }

    for (final mode in modes) {
      final name = '$mode-$flavor';
      final xcconfig = _ensureXcconfig(
        owned,
        path: xcconfigPath(mode),
        claimExisting: claimExisting,
      );

      final projectList = project.buildConfigurationList;
      final projectConfig = owned.ensure<XCBuildConfiguration>(
        (g, u) => XCBuildConfiguration(g, u),
        flavor: flavor,
        kind: ['buildConfiguration', mode],
        existing: () => projectList[name],
        claimExisting: claimExisting,
        create: (config) {
          final base = projectList[mode];

          config.name = name;
          config.buildSettings = _copy({
            ...?base?.buildSettings,
            ...buildSettings,
          });
          projectList.buildConfigurations.add(config);
        },
      );
      settings?.apply(
        projectConfig,
        scope: OwnedBuildSettings.projectScope,
        wanted: buildSettings,
      );
      _follow(owned, projectConfig, xcconfig);

      final targetConfig = owned.ensure<XCBuildConfiguration>(
        (g, u) => XCBuildConfiguration(g, u),
        target: targetName,
        flavor: flavor,
        kind: ['buildConfiguration', mode],
        existing: () => targetList[name],
        claimExisting: claimExisting,
        create: (config) {
          config.name = name;
          config.buildSettings = _copy(_targetSettings);
          targetList.buildConfigurations.add(config);
        },
      );
      settings?.apply(
        targetConfig,
        scope: OwnedBuildSettings.targetScope,
        wanted: _targetSettings,
      );
      _follow(owned, targetConfig, xcconfig);
    }
  }

  /// The base configuration of an owned configuration is the xcconfig file of
  /// its flavor, wherever it is now. The one of a configuration that existed is
  /// only filled in.
  static void _follow(
    OwnedObjects owned,
    XCBuildConfiguration config,
    PBXFileReference xcconfig,
  ) {
    if (owned.owned.contains(config.uuid)) {
      config.baseConfigurationReference = xcconfig;
    } else {
      config.baseConfigurationReference ??= xcconfig;
    }
  }

  /// The reference to the xcconfig file at [path].
  ///
  /// What identifies it is the **path**, not the flavor: flavors that ask for
  /// the same file share one reference, whichever of them comes first, and a
  /// flavor that moves to another path asks for another reference, leaving the
  /// old one to the flavors that still ask for it (and to
  /// [OwnedObjects.settle], which removes it when none does). So nothing
  /// depends on the order the flavors are processed in, nor on which one made a
  /// file the others share.
  ///
  /// The one that `ios:xcconfig` made is found by its path and used as it is
  /// (see `ensureXcconfigReference`: it has a seed of its own, so the two
  /// processors never own the same object).
  static PBXFileReference _ensureXcconfig(
    OwnedObjects owned, {
    required String path,
    required bool claimExisting,
  }) {
    final project = owned.project;

    return owned.ensure<PBXFileReference>(
      (g, u) => PBXFileReference(g, u),
      kind: ['fileReference', ...path.split('/')],
      existing: () =>
          project.files.where((file) => file.path == path).firstOrNull,
      claimExisting: claimExisting,
      create: (file) {
        file.path = path;
        file.sourceTree = '<group>';
        file.lastKnownFileType = 'text.xcconfig';
        project.mainGroup.children.add(file);
      },
    );
  }

  /// A deep copy of [value], so that two configurations never share a list.
  static Map<String, dynamic> _copy(Map<String, dynamic> value) => {
    for (final entry in value.entries) entry.key: _copyValue(entry.value),
  };

  static Object? _copyValue(Object? value) => switch (value) {
    Map() => {
      for (final entry in value.entries) entry.key: _copyValue(entry.value),
    },
    List() => [for (final item in value) _copyValue(item)],
    _ => value,
  };
}
