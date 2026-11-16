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
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_flavorizr/src/engine/artifact.dart';
import 'package:flutter_flavorizr/src/engine/flavorizr_context.dart';
import 'package:flutter_flavorizr/src/engine/flavorizr_processor.dart';
import 'package:flutter_flavorizr/src/engine/processors/android/android_icon_source.dart';
import 'package:flutter_flavorizr/src/exception/file_not_found_exception.dart';
import 'package:flutter_flavorizr/src/exception/malformed_resource_exception.dart';
import 'package:flutter_flavorizr/src/parser/models/flavors/android/adaptive_icon.dart';
import 'package:flutter_flavorizr/src/processors/android/icons/android_generate_iclauncher_xml_processor.dart';
import 'package:flutter_flavorizr/src/utils/constants.dart';
import 'package:path/path.dart' as p;
import 'package:sprintf/sprintf.dart';

/// Generates the launcher icons of the flavors, below
/// `android/app/src/<flavor>/res`.
///
/// For every Android flavor:
///
/// * when it has an `icon` (`android.icon`, otherwise `app.icon`), the
///   `ic_launcher.png` of every `mipmap-*` density;
/// * when it has an `adaptiveIcon`, the `ic_launcher.xml` of
///   `mipmap-anydpi-v26` and the foreground, background and (if any) monochrome
///   PNGs of every `drawable-*` density.
///
/// Every file is [Artifact.managed]: it is generated whole from a source icon,
/// so it is hashed in the lock and a hand edit of it is a conflict. A flavor
/// without icons, or one that was dropped, simply produces nothing: the files
/// of a previous run are cleaned by the reconciliation of stale artifacts.
///
/// The source icons are user inputs, read from the real project (a path
/// relative to it, which must stay inside it, links included); the output goes
/// to the workspace. Everything is read and rendered before the first file is
/// written, so a missing or broken source leaves the workspace untouched. The
/// output is deterministic (see [AndroidIconSource]): the same sources always
/// produce the same bytes.
///
/// The placeholder icons of `android:dummyAssets` are not produced here. They
/// come from the assets that 2.x downloads, which is not part of this
/// processor; when that processor exists this one runs after it, so the icons
/// of the user win over the placeholders.
class AndroidIconsProcessor extends FlavorizrProcessor {
  /// Creates the processor.
  const AndroidIconsProcessor();

  static const _iconSizes = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
  };

  static const _adaptiveIconSizes = {
    'drawable-mdpi': 108,
    'drawable-hdpi': 162,
    'drawable-xhdpi': 216,
    'drawable-xxhdpi': 324,
    'drawable-xxxhdpi': 432,
  };

  @override
  String get id => 'android:icons';

  @override
  Set<String> get after => const {'android:dummyAssets'};

  @override
  Future<void> apply(FlavorizrContext ctx) async {
    // The PNGs rendered so far by source path and size. A decoded source is
    // dropped as soon as its sizes are rendered, so only small PNGs are kept
    // while many flavors, or many sources, are processed.
    final rendered = <String, Map<int, Uint8List>>{};
    final outputs = <String, Uint8List>{};

    Future<void> addPngs(
      String flavor,
      String pathTemplate,
      Map<String, int> sizes,
      String sourcePath,
    ) async {
      final pngs = await _render(ctx, rendered, sourcePath, sizes.values);

      for (final MapEntry(key: folder, value: size) in sizes.entries) {
        outputs[sprintf(pathTemplate, [flavor, folder])] = pngs[size]!;
      }
    }

    for (final MapEntry(key: flavor, value: definition)
        in ctx.config.androidFlavors.entries) {
      final android = definition.android!;
      final iconPath = android.icon ?? definition.app.icon;
      final adaptiveIcon = android.adaptiveIcon;

      if (iconPath == null && adaptiveIcon == null) {
        continue;
      }

      _checkFlavorName(flavor);

      if (iconPath != null) {
        await addPngs(flavor, K.androidIconPath, _iconSizes, iconPath);
      }

      if (adaptiveIcon != null) {
        final layers = {
          K.androidAdaptiveIconForegroundPath: adaptiveIcon.foreground,
          K.androidAdaptiveIconBackgroundPath: adaptiveIcon.background,
          if (adaptiveIcon.monochrome != null)
            K.androidAdaptiveIconMonochromePath: adaptiveIcon.monochrome!,
        };

        for (final MapEntry(key: template, value: layerPath)
            in layers.entries) {
          await addPngs(flavor, template, _adaptiveIconSizes, layerPath);
        }

        outputs[sprintf(K.androidAdaptiveIconXmlPath, [
          flavor,
        ])] = Uint8List.fromList(
          utf8.encode(_adaptiveIconXml(ctx, adaptiveIcon)),
        );
      }
    }

    for (final MapEntry(key: path, value: bytes) in outputs.entries) {
      final target = File(ctx.resolve(path));

      await target.parent.create(recursive: true);
      await target.writeAsBytes(bytes);
      ctx.track(Artifact.managed(path));
    }
  }

  /// The PNGs of [sizes] (squares) of the source at [path], from [rendered] or,
  /// for the sizes it does not hold yet, rendered and stored there.
  static Future<Map<int, Uint8List>> _render(
    FlavorizrContext ctx,
    Map<String, Map<int, Uint8List>> rendered,
    String path,
    Iterable<int> sizes,
  ) async {
    final pngs = rendered.putIfAbsent(p.normalize(path), () => {});
    final missing = sizes.where((size) => !pngs.containsKey(size)).toList();

    if (missing.isNotEmpty) {
      final source = await _load(ctx, path);

      for (final size in missing) {
        pngs[size] = source.renderPng(size, size);
      }
    }

    return pngs;
  }

  static String _adaptiveIconXml(FlavorizrContext ctx, AdaptiveIcon icon) =>
      AndroidGenerateIclauncherXmlProcessor(
        adaptiveIcon: icon,
        config: ctx.config,
        logger: ctx.logger,
      ).execute();

  /// A flavor name becomes a directory, so it must be a single path segment:
  /// `../main` or `a/b` would write somewhere else in the project.
  static void _checkFlavorName(String flavor) {
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

  /// Reads and decodes the source icon at [path], relative to the project.
  static Future<AndroidIconSource> _load(
    FlavorizrContext ctx,
    String path,
  ) async {
    final resolved = ctx.resolveProject(path);

    switch (FileSystemEntity.typeSync(resolved)) {
      case FileSystemEntityType.notFound:
        throw FileNotFoundException(path);
      case FileSystemEntityType.file:
        break;
      default:
        throw MalformedResourceException(path);
    }

    // `resolve` is lexical: a link inside the project may still lead out of it.
    final real = await File(resolved).resolveSymbolicLinks();
    final realProject = await ctx.projectRoot.resolveSymbolicLinks();

    if (!p.isWithin(realProject, real)) {
      throw ArgumentError.value(
        path,
        'icon',
        'must stay within `${ctx.projectRoot.path}`, links included',
      );
    }

    final file = File(real);

    // Checked before reading, so that a huge file is never loaded; `decode`
    // checks again for the callers that already hold the bytes.
    if (await file.length() > AndroidIconSource.maxBytes) {
      throw MalformedResourceException(path);
    }

    return AndroidIconSource.decode(await file.readAsBytes(), name: path);
  }
}
