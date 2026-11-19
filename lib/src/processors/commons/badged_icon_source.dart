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

import 'package:flutter_flavorizr/src/badge/badge_source_icon.dart';
import 'package:flutter_flavorizr/src/badge/project_badge_source_files.dart';
import 'package:flutter_flavorizr/src/badge/resolved_badge.dart';
import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';

/// The image the icons of the flavor [flavor] are made from, and the badge to
/// draw on them, or `null` when it has no icons to make.
///
/// A flavor with no badge has the icons of its [icon] and none without it. One
/// with a badge always has them: the source is chosen as
/// `resolveBadgeSourceIcon` does (its [icon], the `icon` of the root, the
/// `AppIcon` of the project), and the run fails with a hint when none is 512 px
/// or more. The paths are relative to the current directory, which the
/// processors that are not on the engine treat as the project.
({String source, ResolvedBadge? badge})? badgedIconSource(
  FlavorizrConfig config,
  String flavor, {
  String? icon,
}) {
  final badge = config.badgeOf(flavor);

  if (badge == null) {
    return icon == null ? null : (source: icon, badge: null);
  }

  final source = resolveBadgeSourceIcon(
    flavorIcon: icon,
    rootIcon: config.icon,
    files: ProjectBadgeSourceFiles(Directory('.')),
  );

  return (source: source.path, badge: badge);
}
