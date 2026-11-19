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

import 'package:dart_xcodeproj/dart_xcodeproj.dart';
import 'package:flutter_flavorizr/src/engine/artifact.dart';
import 'package:flutter_flavorizr/src/engine/flavorizr_context.dart';
import 'package:flutter_flavorizr/src/engine/flavorizr_processor.dart';
import 'package:flutter_flavorizr/src/engine/processors/darwin/scheme_editor.dart';
import 'package:flutter_flavorizr/src/engine/processors/darwin/xcconfig_naming.dart';
import 'package:flutter_flavorizr/src/engine/resource_key.dart';
import 'package:flutter_flavorizr/src/engine/resources/xcodeproj_resource.dart';
import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:flutter_flavorizr/src/parser/models/flavors/flavor.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

const _testProductTypes = {
  'com.apple.product-type.bundle.unit-test',
  'com.apple.product-type.bundle.ui-testing',
};

/// Whether Swift Package Manager is enabled for the project, which is what
/// decides if the schemes of the flavors get the pre-action of Flutter.
///
/// It is on unless the `pubspec.yaml` of the project turns it off, as Flutter
/// reads it (`flutter: config: enable-swift-package-manager: false`): that is
/// the setting a project carries. The global one (`flutter config`) and the
/// version of Xcode are Flutter's to look at, not something a file of the
/// project says, so they are not. A pre-action in a scheme of a project that
/// does not use Swift Package Manager runs a script that has nothing to prepare.
bool swiftPackageManagerEnabled(FlavorizrContext ctx) {
  final pubspec = File(ctx.resolveProject('pubspec.yaml'));

  if (!pubspec.existsSync()) return true;

  try {
    final yaml = loadYaml(pubspec.readAsStringSync());
    final flutter = yaml is YamlMap ? yaml['flutter'] : null;
    final config = flutter is YamlMap ? flutter['config'] : null;

    return !(config is YamlMap &&
        config['enable-swift-package-manager'] == false);
  } on YamlException {
    return true;
  }
}

/// The schemes of the flavors of a Darwin platform, one `<flavor>.xcscheme` in
/// the shared schemes of the Xcode project.
///
/// A scheme is **patched** (see [SchemeEditor]): the file is the user's, Xcode's
/// and Flutter's, and flavorizr owns the `buildConfiguration` of the Launch,
/// Test, Profile, Analyze and Archive actions, plus the existence of the file.
///
/// * A scheme that is **not there** is made, with the target of the app, its
///   test targets, and the pre-action of Flutter when Swift Package Manager is
///   enabled ([swiftPackageManagerEnabled]), so that it builds from Xcode and
///   from `flutter build` and Flutter has nothing to add to it.
/// * A scheme that **is there** has the build configuration of the five actions
///   set, and nothing else touched: a pre-action Flutter injected, the ones of
///   the user, the arguments, the environment and the layout are kept. It is not
///   written when the build configurations are right already, so a run after
///   Flutter injected its pre-action changes nothing.
///
/// The Xcode project is read, never changed: it is the shared `xcodeproj`
/// resource, for the target the scheme builds.
///
/// The scheme of a flavor that was dropped stays: a patched file is shared with
/// the user, and the lock stops owning it.
abstract class DarwinSchemeProcessor extends FlavorizrProcessor {
  /// Creates a processor.
  const DarwinSchemeProcessor();

  /// The Xcode project bundle, relative to the project.
  String get projectPath;

  /// The key of the shared resource of the Xcode project.
  ResourceKey<XcodeProject> get projectKey;

  /// The script Flutter prepares the scheme with, on this platform.
  PrepareScript get prepareScript;

  /// The flavors of the platform.
  Map<String, Flavor> flavors(FlavorizrConfig config);

  /// Where the scheme of [flavor] is, relative to the project.
  String schemePath(String flavor) => p.posix.join(
    projectPath,
    'xcshareddata',
    'xcschemes',
    '$flavor.xcscheme',
  );

  @override
  Set<ResourceKey<Object?>> get requires => {projectKey};

  @override
  Future<void> apply(FlavorizrContext ctx) async {
    final project = ctx.resource(projectKey);
    final names = flavors(ctx.config).keys.toList(growable: false);

    // Checked before the first file is written.
    names.forEach(checkFlavorName);

    final spm = swiftPackageManagerEnabled(ctx);

    for (final flavor in names) {
      final path = schemePath(flavor);
      final file = File(ctx.resolve(path));

      if (file.existsSync()) {
        final scheme = await XCScheme.open(file.path);

        if (SchemeEditor.setBuildConfigurations(scheme, flavor)) {
          ctx.logger.detail('[$id] Patching `$path`');

          await scheme.save();
        }
      } else {
        ctx.logger.detail('[$id] Writing `$path`');

        await file.parent.create(recursive: true);
        await _create(
          project,
          flavor,
          withPrepareAction: spm,
        ).saveAs(file.path);
      }

      ctx.track(Artifact.patched(path));
    }
  }

  /// The scheme of [flavor], new: what 2.x wrote, with an entry to build the
  /// app, which Xcode needs to build anything, and the pre-action of Flutter
  /// when [withPrepareAction].
  XCScheme _create(
    XcodeProject project,
    String flavor, {
    required bool withPrepareAction,
  }) {
    final target = project.nativeTargets.firstOrNull;
    final name = target?.name;

    if (target == null || name == null) {
      throw StateError(
        'The project has no native target with a name to make the scheme of '
        '`$flavor` for.',
      );
    }

    final scheme = XCScheme.create();
    final container = 'container:${project.name}.xcodeproj';

    // The product of the app is named after its target: `ios:buildTargets` and
    // `macos:buildTargets` set `PRODUCT_NAME` of the configurations of the
    // flavors to `$(TARGET_NAME)`, which is what the scheme builds. It is not
    // the name of the product reference of the project, which is the one of the
    // app on macOS (`my_app.app`) and is what the configurations of the flavors
    // override.
    BuildableReference reference(
      PBXNativeTarget target,
      String extension,
    ) => BuildableReference()
      ..setReferenceTarget(
        target.uuid,
        '${extension == 'app' ? target.name : target.productName ?? target.name}'
        '.$extension',
        target.name!,
        container,
      );

    SchemeEditor.setBuildConfigurations(scheme, flavor);

    final app = reference(target, 'app');

    scheme.buildAction.addEntry(
      BuildActionEntry()
        ..buildForTesting = true
        ..buildForRunning = true
        ..buildForProfiling = true
        ..buildForArchiving = true
        ..buildForAnalyzing = true
        ..addBuildableReference(app),
    );

    final runnable = BuildableProductRunnable()
      ..runnableDebuggingMode = '0'
      ..buildableReference = app;

    scheme.launchAction.buildableProductRunnable = runnable;
    scheme.profileAction.buildableProductRunnable = runnable;
    scheme.testAction.addMacroExpansion(
      MacroExpansion()..setBuildableReference(app),
    );

    for (final test in project.nativeTargets.where(
      (target) => _testProductTypes.contains(target.productType),
    )) {
      scheme.testAction.addTestable(
        TestableReference()
          ..skipped = false
          ..parallelizable = false
          ..addBuildableReference(reference(test, 'xctest')),
      );
    }

    if (withPrepareAction) {
      SchemeEditor.addPrepareAction(scheme, prepareScript, app);
    }

    return scheme;
  }
}

/// `ios:schema`: the schemes of the iOS flavors, in
/// `ios/Runner.xcodeproj/xcshareddata/xcschemes`. See [DarwinSchemeProcessor].
class IosSchemaProcessor extends DarwinSchemeProcessor {
  /// Creates the processor.
  const IosSchemaProcessor();

  @override
  String get id => 'ios:schema';

  @override
  Set<String> get after => const {'ios:buildTargets'};

  @override
  String get projectPath => XcodeprojResource.iosProject;

  @override
  ResourceKey<XcodeProject> get projectKey => XcodeprojResource.iosKey;

  @override
  PrepareScript get prepareScript => PrepareScript.ios;

  @override
  Map<String, Flavor> flavors(FlavorizrConfig config) => config.iosFlavors;
}

/// `macos:schema`: the schemes of the macOS flavors, in
/// `macos/Runner.xcodeproj/xcshareddata/xcschemes`. See [DarwinSchemeProcessor].
///
/// It differs from `ios:schema` in the project it reads and in the script of the
/// pre-action only. macOS has no launch screen, and no other part of a scheme
/// depends on the platform.
class MacosSchemaProcessor extends DarwinSchemeProcessor {
  /// Creates the processor.
  const MacosSchemaProcessor();

  @override
  String get id => 'macos:schema';

  @override
  Set<String> get after => const {'macos:buildTargets'};

  @override
  String get projectPath => XcodeprojResource.macosProject;

  @override
  ResourceKey<XcodeProject> get projectKey => XcodeprojResource.macosKey;

  @override
  PrepareScript get prepareScript => PrepareScript.macos;

  @override
  Map<String, Flavor> flavors(FlavorizrConfig config) => config.macosFlavors;
}
