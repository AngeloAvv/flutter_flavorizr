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

import 'dart:typed_data';

import 'package:flutter_flavorizr/src/engine/artifact.dart';
import 'package:flutter_flavorizr/src/engine/flavorizr_context.dart';
import 'package:flutter_flavorizr/src/engine/flavorizr_processor.dart';
import 'package:flutter_flavorizr/src/engine/processors/darwin/xcconfig_naming.dart';
import 'package:flutter_flavorizr/src/engine/processors/icon_inputs.dart';
import 'package:flutter_flavorizr/src/engine/processors/icon_source_loader.dart';
import 'package:flutter_flavorizr/src/parser/models/flavors/flavor.dart';
import 'package:flutter_flavorizr/src/utils/constants.dart';

/// The `icon` of [flavor] for Windows: the one of the platform, otherwise the one
/// of the app.
String? windowsIconOf(Flavor flavor) => flavor.windows?.icon ?? flavor.app.icon;

/// The `.ico` of the flavor [flavorName], relative to the project.
String windowsIcoPath(String flavorName) =>
    '${K.windowsIconsPath}/$flavorName.ico';

/// Whether `windows:icons` makes an `.ico` for the flavor [flavorName]: it has
/// an `icon` (the one of the platform, otherwise the one of the app), or a badge
/// (see `FlavorizrConfig.badgeOf`), for which the icon is made from the source
/// the badge is drawn on.
///
/// It is the one condition the icons processor and `windows:cmake` decide by,
/// so that the flavor is pointed at the `.ico` that this run makes, and at no
/// other.
bool windowsMakesIcon(FlavorizrContext ctx, String flavorName, Flavor flavor) =>
    windowsIconOf(flavor) != null || ctx.config.badgeOf(flavorName) != null;

/// Makes the `<flavor>.ico` of each Windows flavor, in
/// `windows/runner/resources`.
///
/// For every flavor that has icons (see [windowsMakesIcon]) the `.ico` packs the
/// source icon at 16, 32, 48 and 256 px, the sizes a Win32 app asks for (the
/// taskbar, Alt+Tab, the shortcut and the thumbnail of Explorer). With a badge
/// the icon is made from the source the badge is drawn on (see
/// `resolveBadgeSourceIcon`: the `icon` of the flavor if it is big enough, the
/// `icon` of the root, the `AppIcon` of the project), and the band is drawn on
/// every size, at that size. A flavor with neither builds with the
/// `app_icon.ico` of the project, and has no `.ico` (see
/// `WindowsRunnerCMakeListsPatchProcessor`).
///
/// Every file is [Artifact.managed]: it is generated whole from a source icon,
/// so it is hashed in the lock and a hand edit of it is a conflict. It also
/// records the hash of its inputs (see [iconInputs]): a run that finds the same
/// source and badge, and the file as the lock has it, neither renders nor writes
/// it, so another machine, or another version of the library that encodes the
/// `.ico`, changes nothing. What a flavor
/// does not make anymore (it was dropped, lost its `icon`, or its badge was
/// turned off and it has no `icon`) is not produced, so the reconciliation of
/// stale artifacts removes the file of the previous run. An `.ico` that the lock
/// does not know is the user's: it is kept while the flavor makes none, and it is
/// a conflict when the flavor starts to make one, as for any generated file.
///
/// The source icons are inputs of the user, read from the real project (a path
/// relative to it, which must stay inside it, links included); the output goes
/// to the workspace. Everything is read and rendered before the first file is
/// written, so a missing or broken source leaves the workspace untouched. The
/// output is deterministic: the same sources always produce the same bytes.
///
/// The placeholder `.ico` of 2.x's `dummyAssets` is not made anymore: see
/// `adoptProject` for how the ones a project still has are recognised.
class WindowsIconsProcessor extends FlavorizrProcessor {
  /// The sizes of the frames of an `.ico`, in px.
  static const sizes = [16, 32, 48, 256];

  /// Creates the processor.
  const WindowsIconsProcessor();

  @override
  String get id => 'windows:icons';

  @override
  Set<String> get after => const {'windows:dummyAssets'};

  @override
  Set<String> get paths => {K.windowsIconsPath};

  @override
  Future<void> apply(FlavorizrContext ctx) async {
    // The `.ico` rendered so far, by source and badge: the source of two flavors
    // may be the same. A decoded source is dropped as soon as it is rendered.
    final rendered = <String, Uint8List>{};
    final files = GeneratedIcons(ctx);

    for (final MapEntry(key: flavorName, value: flavor)
        in ctx.config.windowsFlavors.entries) {
      final source = iconSourceOf(ctx, flavorName, windowsIconOf(flavor));

      if (source == null) continue;

      checkFlavorName(flavorName);

      final badge = ctx.config.badgeOf(flavorName);
      final key = [
        source,
        if (badge != null) ...[badge.label, badge.color.hex],
      ].join('\u0000');

      final path = windowsIcoPath(flavorName);
      final inputs = iconInputs(
        kind: 'ico',
        sourceDigest: await files.sourceDigest(source),
        sizes: sizes,
        badge: badge,
      );

      if (await files.keepIfUpToDate(path, inputs)) continue;

      if (!rendered.containsKey(key)) {
        final image = await loadIconSource(ctx, source);

        rendered[key] = image.renderIco(sizes, badge: badge);
      }

      files.add(path, rendered[key]!, inputs: inputs);
    }

    await files.write();
  }
}

/// `windows:dummyAssets`: it makes nothing.
///
/// 2.x built a `<flavor>.ico` from a default icon that it downloaded, for each
/// flavor with no icon. 3.0 does not: such a flavor builds with the
/// `app_icon.ico` of the project, and an `.ico` that exists is the one of
/// `windows:icons` or the user's. What a project still has of the placeholders is
/// recognised by hash, when it is adopted (see `DummyAssets`), and removed by
/// `windows:icons` like any `.ico` it does not make anymore.
///
/// The id stays so that a recipe that names it still runs, and so that
/// `windows:icons` is ordered after it, as it always was.
class WindowsDummyAssetsProcessor extends FlavorizrProcessor {
  /// Creates the processor.
  const WindowsDummyAssetsProcessor();

  @override
  String get id => 'windows:dummyAssets';

  @override
  Future<void> apply(FlavorizrContext ctx) async {}
}
