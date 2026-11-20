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
import 'package:flutter_flavorizr/src/engine/darwin/darwin_build_configurations.dart';
import 'package:flutter_flavorizr/src/engine/darwin/owned_build_settings.dart';
import 'package:flutter_flavorizr/src/engine/darwin/owned_objects.dart';
import 'package:flutter_flavorizr/src/engine/flavorizr_context.dart';
import 'package:flutter_flavorizr/src/engine/flavorizr_processor.dart';
import 'package:flutter_flavorizr/src/engine/processors/darwin/xcconfig_naming.dart';
import 'package:flutter_flavorizr/src/engine/processors/darwin/xcconfig_sources.dart';
import 'package:flutter_flavorizr/src/engine/resource_key.dart';
import 'package:flutter_flavorizr/src/engine/resources/xcodeproj_resource.dart';
import 'package:flutter_flavorizr/src/parser/mixins/build_settings_mixin.dart';
import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:flutter_flavorizr/src/parser/models/flavors/darwin/enums.dart';
import 'package:flutter_flavorizr/src/parser/models/flavors/flavor.dart';
import 'package:flutter_flavorizr/src/engine/processors/darwin/darwin_icon_name.dart';
import 'package:flutter_flavorizr/src/utils/constants.dart';
import 'package:path/path.dart' as p;

/// The base of `ios:buildTargets` and `macos:buildTargets`: the build
/// configurations of the flavors of an Apple platform, `<Mode>-<flavor>`, in
/// the project and in its first target, pointing at the xcconfig files of the
/// flavor.
///
/// They are made through `DarwinBuildConfigurations`, so they have a UUID of
/// their own and are removed with their flavor. What this processor adds to
/// that is the **settings**: the ones of the configuration are edited key by
/// key, never replaced (see `OwnedBuildSettings`):
///
/// * the settings of the yaml (`buildSettings` of the app and of the flavor,
///   starting from the defaults of the platform) and `PRODUCT_NAME` of the
///   target are set, and recorded in the lock, key by key, with the hash of the
///   value;
/// * every other setting of the configuration is left as it is: the
///   `DEVELOPMENT_TEAM` a user picks in Xcode survives a run (#340);
/// * a setting that left the yaml is removed, only when it still holds the
///   value flavorizr wrote, and
/// * an owned setting that was edited by hand is a conflict: the lock hashes
///   them (see `buildSettingsOwnedContent`), so the run does not write over
///   it without the user's say.
///
/// The project is the shared `xcodeproj:<platform>`: it is not opened or saved
/// here, and the processor tracks it, as a patched artifact.
abstract class _BuildTargetsProcessor extends FlavorizrProcessor {
  const _BuildTargetsProcessor();

  /// The resource of the project.
  ResourceKey<Object?> get projectKey;

  /// The objects of the project of [ctx].
  OwnedObjects owned(FlavorizrContext ctx);

  /// The flavors of the platform.
  Map<String, Flavor> flavors(FlavorizrConfig config);

  /// The build settings of [flavorName], from the defaults of the platform to
  /// the ones of the flavor.
  Map<String, dynamic> buildSettings(
    FlavorizrContext ctx,
    String flavorName,
    Flavor flavor,
  );

  /// The folder of the xcconfig files of the flavors, relative to the project
  /// of the platform: how the file references of the project spell their path.
  String get xcconfigFolder;

  @override
  Set<ResourceKey<Object?>> get requires => {projectKey};

  @override
  Future<void> apply(FlavorizrContext ctx) async {
    final objects = owned(ctx);
    final settings = OwnedBuildSettings(objects);
    final selected = flavors(ctx.config);

    for (final flavorName in selected.keys) {
      checkFlavorName(flavorName);
    }

    for (final MapEntry(key: flavorName, value: flavor) in selected.entries) {
      DarwinBuildConfigurations.ensure(
        objects,
        flavor: flavorName,
        buildSettings: buildSettings(ctx, flavorName, flavor),
        xcconfigPath: (mode) => p.posix.join(
          xcconfigFolder,
          xcconfigName(flavorName, Target.values.byName(mode.toLowerCase())),
        ),
        settings: settings,
      );
    }

    ctx.logger.detail(
      '[$id] Removed ${settings.settle().length} setting(s) flavorizr no '
      'longer wants',
    );

    // A configuration that goes with its flavor takes with it whatever is in
    // it: the ones that hold settings of the user (a `DEVELOPMENT_TEAM`) stay.
    for (final uuid in ctx.previousObjectsOf(objects.artifact.path)) {
      final object = objects.project.objectsByUuid[uuid];

      if (!objects.owned.contains(uuid) &&
          object is XCBuildConfiguration &&
          settings.holdsOthers(object)) {
        ctx.logger.detail(
          '[$id] Keeping `${object.name}`: it holds settings of its own',
        );
        objects.release(object);
      }
    }

    objects.settle();

    ctx.track(objects.artifact);
  }

  /// The resolved `buildSettings` of [flavorName], where [app] and [own] are
  /// the ones of the app and of the flavor for the platform.
  Map<String, dynamic> resolveSettings(
    FlavorizrContext ctx,
    String flavorName, {
    required Map<String, dynamic> defaults,
    required Map<String, dynamic>? app,
    required Map<String, dynamic> own,
    required Map<String, dynamic> userApp,
    required String assetsPath,
    required bool hasIcon,
  }) => DarwinIconName.resolve(
    {...app ?? defaults, ...own},
    assetsPath: ctx.resolveProject(assetsPath),
    flavorName: flavorName,
    // A flavor with a badge has the icons that are made for it.
    hasIcon: hasIcon || ctx.config.badgeOf(flavorName) != null,
    // The set of a flavor that lost its icon is the one `ios:icons` made, and
    // removes: it is not the one the flavor builds with.
    generated: ctx.hasPreviousFile(
      '$assetsPath/AppIcon-$flavorName.appiconset',
    ),
    chosen:
        userApp.containsKey(DarwinIconName.setting) ||
        own.containsKey(DarwinIconName.setting),
  );
}

/// `ios:buildTargets`: the build configurations of the iOS flavors.
class IosBuildTargetsProcessor extends _BuildTargetsProcessor {
  /// Creates the processor.
  const IosBuildTargetsProcessor();

  @override
  String get id => 'ios:buildTargets';

  @override
  Set<String> get after => const {'ios:xcconfig'};

  @override
  ResourceKey<Object?> get projectKey => XcodeprojResource.iosKey;

  @override
  OwnedObjects owned(FlavorizrContext ctx) => OwnedObjects.ios(ctx);

  @override
  String get xcconfigFolder =>
      p.posix.relative(K.iOSFlutterPath, from: K.iOSPath);

  @override
  Map<String, Flavor> flavors(FlavorizrConfig config) => config.iosFlavors;

  @override
  Map<String, dynamic> buildSettings(
    FlavorizrContext ctx,
    String flavorName,
    Flavor flavor,
  ) => resolveSettings(
    ctx,
    flavorName,
    defaults: BuildSettingsMixin.iosDefaultBuildSettings,
    app: ctx.config.app?.ios?.buildSettings,
    own: flavor.ios!.buildSettings,
    userApp: ctx.config.app?.ios?.userBuildSettings ?? const {},
    assetsPath: K.iOSAssetsPath,
    hasIcon: flavor.app.icon != null || flavor.ios?.icon != null,
  );
}

/// `macos:buildTargets`: the build configurations of the macOS flavors, which
/// build with the xcconfig files of `macos/Runner/Configs`.
class MacosBuildTargetsProcessor extends _BuildTargetsProcessor {
  /// Creates the processor.
  const MacosBuildTargetsProcessor();

  @override
  String get id => 'macos:buildTargets';

  @override
  Set<String> get after => const {'macos:configs'};

  @override
  ResourceKey<Object?> get projectKey => XcodeprojResource.macosKey;

  @override
  OwnedObjects owned(FlavorizrContext ctx) => OwnedObjects.macos(ctx);

  @override
  String get xcconfigFolder =>
      p.posix.relative(K.macOSConfigsPath, from: K.macOSPath);

  @override
  Map<String, Flavor> flavors(FlavorizrConfig config) => config.macosFlavors;

  @override
  Map<String, dynamic> buildSettings(
    FlavorizrContext ctx,
    String flavorName,
    Flavor flavor,
  ) => resolveSettings(
    ctx,
    flavorName,
    defaults: BuildSettingsMixin.macosDefaultBuildSettings,
    app: ctx.config.app?.macos?.buildSettings,
    own: flavor.macos?.buildSettings ?? const {},
    userApp: ctx.config.app?.macos?.userBuildSettings ?? const {},
    assetsPath: K.macOSAssetsPath,
    hasIcon: flavor.app.icon != null || flavor.macos?.icon != null,
  );
}
