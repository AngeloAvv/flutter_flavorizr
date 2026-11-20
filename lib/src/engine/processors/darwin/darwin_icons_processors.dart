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

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_flavorizr/src/engine/artifact.dart';
import 'package:flutter_flavorizr/src/engine/flavorizr_context.dart';
import 'package:flutter_flavorizr/src/engine/flavorizr_processor.dart';
import 'package:flutter_flavorizr/src/engine/processors/darwin/darwin_icon_sets.dart';
import 'package:flutter_flavorizr/src/engine/processors/darwin/xcconfig_naming.dart';
import 'package:flutter_flavorizr/src/engine/processors/icon_inputs.dart';
import 'package:flutter_flavorizr/src/engine/processors/icon_source_loader.dart';
import 'package:flutter_flavorizr/src/models/darwin/icon/darwin_icon.dart';
import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:flutter_flavorizr/src/parser/models/flavors/flavor.dart';
import 'package:flutter_flavorizr/src/utils/constants.dart';

/// Makes the `AppIcon-<flavor>.appiconset` of each flavor of an Apple platform,
/// in the asset catalog of the app.
///
/// For every flavor that has icons (see [sourceOf]):
///
/// * every PNG of the set, resized from the source icon;
/// * its `Contents.json`, generated in code (see [darwinIconContents]).
///
/// A flavor has icons when it has an `icon` (the one of the platform, otherwise
/// the one of the app) or a badge (see `FlavorizrConfig.badgeOf`). With a badge
/// the icons are made from the source the badge is drawn on (see
/// `resolveBadgeSourceIcon`: the `icon` of the flavor if it is big enough, the
/// `icon` of the root, the `AppIcon` of the project) and the band is drawn on
/// them, at the size of each one. A flavor with neither builds with the
/// `AppIcon` of the project (see `DarwinIconName`), and has no set.
///
/// Every file is [Artifact.managed]: it is generated whole from a source icon,
/// so it is hashed in the lock and a hand edit of it is a conflict. The PNGs
/// also record the hash of their inputs (see [iconInputs]): a run that finds the
/// same source, size and badge, and the file as the lock has it, neither renders
/// nor writes it, so another machine, or another version of the library that
/// encodes the PNGs, changes nothing. What a flavor
/// does not make anymore (it was dropped, lost its `icon`, or its badge was
/// turned off and it has no `icon`) is not produced, so the reconciliation of
/// stale artifacts removes the files of the previous run, and copy-back the
/// folder that leaves empty. A file of the user in the folder is never touched,
/// and keeps it.
///
/// The source icons are inputs of the user, read from the real project (a path
/// relative to it, which must stay inside it, links included); the output goes
/// to the workspace. Everything is read and rendered before the first file is
/// written, so a missing or broken source leaves the workspace untouched. The
/// output is deterministic: the same sources always produce the same bytes.
///
/// The placeholder icons of 2.x's `dummyAssets` are not made anymore: see
/// `adoptProject` for how the ones a project still has are recognised.
abstract class DarwinIconsProcessor extends FlavorizrProcessor {
  /// Creates the processor.
  const DarwinIconsProcessor();

  /// The flavors of the platform, by name.
  Map<String, Flavor> flavors(FlavorizrConfig config);

  /// The `icon` of [flavor] for the platform, if it has one of its own.
  String? platformIcon(Flavor flavor);

  /// The folder of the asset catalog the sets are in, relative to the project.
  String get assetsPath;

  /// The icons of a set.
  List<DarwinIcon> get icons;

  @override
  Set<String> get paths => {assetsPath};

  /// The folder of the set of [flavor], relative to the project.
  String setPath(String flavor) => '$assetsPath/AppIcon-$flavor.appiconset';

  /// The image the icons of [flavorName] are made from, relative to the
  /// project, or `null` when the flavor has none to make.
  ///
  /// A flavor with a badge always has one, which is the first of the choices of
  /// `resolveBadgeSourceIcon`, and the run fails with a hint when there is none.
  String? sourceOf(FlavorizrContext ctx, String flavorName, Flavor flavor) =>
      iconSourceOf(ctx, flavorName, platformIcon(flavor) ?? flavor.app.icon);

  @override
  Future<void> apply(FlavorizrContext ctx) async {
    // The PNGs rendered so far, by source and badge, and then by size: the
    // source of two flavors may be the same, and the 2x of a size is the 1x of
    // another. A decoded source is dropped as soon as its sizes are rendered.
    final rendered = <String, Map<int, Uint8List>>{};
    final files = GeneratedIcons(ctx);

    for (final MapEntry(key: flavorName, value: flavor) in flavors(
      ctx.config,
    ).entries) {
      final source = sourceOf(ctx, flavorName, flavor);

      if (source == null) continue;

      checkFlavorName(flavorName);

      final badge = ctx.config.badgeOf(flavorName);
      final key = [
        source,
        if (badge != null) ...[badge.label, badge.color.hex],
      ].join('\u0000');
      final pngs = rendered.putIfAbsent(key, () => {});
      final set = setPath(flavorName);
      final digest = await files.sourceDigest(source);
      // What is not up to date, by path.
      final stale = <String, ({int size, String inputs})>{};

      files.add(
        '$set/${K.darwinAppIconContentsFileName}',
        utf8.encode(darwinIconContents(icons)),
      );

      for (final icon in icons) {
        final path = '$set/${icon.fileName}';
        final size = icon.imageSize.width.toInt();
        final inputs = iconInputs(
          kind: 'png',
          sourceDigest: digest,
          sizes: [size, size],
          badge: badge,
        );

        if (!await files.keepIfUpToDate(path, inputs)) {
          stale[path] = (size: size, inputs: inputs);
        }
      }

      final sizes = {for (final file in stale.values) file.size}
        ..removeAll(pngs.keys);

      if (sizes.isNotEmpty) {
        final image = await files.loadSource(source);

        for (final size in sizes) {
          pngs[size] = image.renderPng(size, size, badge: badge);
        }
      }

      for (final MapEntry(key: path, value: file) in stale.entries) {
        files.add(path, pngs[file.size]!, inputs: file.inputs);
      }
    }

    await files.write();
  }
}

/// `ios:icons`: the `AppIcon-<flavor>.appiconset` of each iOS flavor, in
/// `ios/Runner/Assets.xcassets`.
class IosIconsProcessor extends DarwinIconsProcessor {
  /// Creates the processor.
  const IosIconsProcessor();

  @override
  String get id => 'ios:icons';

  @override
  Set<String> get after => const {'ios:dummyAssets'};

  @override
  Map<String, Flavor> flavors(FlavorizrConfig config) => config.iosFlavors;

  @override
  String? platformIcon(Flavor flavor) => flavor.ios?.icon;

  @override
  String get assetsPath => K.iOSAssetsPath;

  @override
  List<DarwinIcon> get icons => iosIconSet;
}

/// `macos:icons`: the `AppIcon-<flavor>.appiconset` of each macOS flavor, in
/// `macos/Runner/Assets.xcassets`.
class MacosIconsProcessor extends DarwinIconsProcessor {
  /// Creates the processor.
  const MacosIconsProcessor();

  @override
  String get id => 'macos:icons';

  @override
  Set<String> get after => const {'macos:dummyAssets'};

  @override
  Map<String, Flavor> flavors(FlavorizrConfig config) => config.macosFlavors;

  @override
  String? platformIcon(Flavor flavor) => flavor.macos?.icon;

  @override
  String get assetsPath => K.macOSAssetsPath;

  @override
  List<DarwinIcon> get icons => macosIconSet;
}
