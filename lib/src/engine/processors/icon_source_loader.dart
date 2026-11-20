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

import 'package:flutter_flavorizr/src/badge/badge_source_icon.dart';
import 'package:flutter_flavorizr/src/badge/project_badge_source_files.dart';
import 'package:flutter_flavorizr/src/engine/flavorizr_context.dart';
import 'package:flutter_flavorizr/src/engine/processors/android/android_icon_source.dart';
import 'package:flutter_flavorizr/src/exception/file_not_found_exception.dart';
import 'package:flutter_flavorizr/src/exception/invalid_configuration_exception.dart';
import 'package:flutter_flavorizr/src/exception/malformed_resource_exception.dart';
import 'package:path/path.dart' as p;

/// Reads and decodes the source icon at [path], relative to the project.
///
/// The icon is an input of the user: it is read from the real project, must
/// stay inside it (links included) and is bounded before it is decoded (see
/// [AndroidIconSource]). Throws a [FileNotFoundException] when there is no
/// file, a [MalformedResourceException] when it is not an image or is too big,
/// and an [ArgumentError] when it leads out of the project.
Future<AndroidIconSource> loadIconSource(
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

/// The image the icons of the flavor [flavorName] are made from, relative to the
/// project, or `null` when it has none to make. [icon] is the `icon` of the
/// flavor for the platform: the one of the platform, or else the one of the app.
///
/// A flavor with no badge has the icons of its [icon] and none without it. One
/// with a badge always has them, from the first of the choices of
/// `resolveBadgeSourceIcon` (its [icon] if it is big enough, the `icon` of the
/// root, the `AppIcon` of the project), and the run fails with a hint when
/// there is none.
String? iconSourceOf(FlavorizrContext ctx, String flavorName, String? icon) {
  if (ctx.config.badgeOf(flavorName) == null) return icon;

  try {
    return resolveBadgeSourceIcon(
      flavorIcon: icon,
      rootIcon: ctx.config.icon,
      files: ProjectBadgeSourceFiles(ctx.projectRoot),
    ).path;
  } on BadgeSourceIconException catch (error) {
    throw InvalidConfigurationException(
      'The flavor `$flavorName` has a badge, and there is no icon to draw it '
      'on: set `icon` for the flavor, or `icon` at the root (1024 px is '
      'best). ${error.tried.isEmpty ? 'No icon was found in the project.' : 'Looked at: ${error.tried.join(', ')}.'}',
    );
  }
}
