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

import 'dart:convert';

import 'package:path/path.dart' as p;

/// The shorter side, in pixels, of the smallest image a badge is drawn on: a
/// smaller one would be scaled up, and blurred.
const minBadgeSourceSize = 512;

/// What the choice of the source icon of a badge reads from the project.
///
/// It is the only thing that touches the disk, so that the choice is a function
/// of what it says. Every path is relative to the root of the project.
abstract interface class BadgeSourceFiles {
  /// The content of the text file at [path], or `null` when there is none.
  String? readText(String path);

  /// The shorter side, in pixels, of the image at [path], or `null` when there
  /// is no such file or it is not an image.
  int? imageSize(String path);
}

/// Where the source icon of a badge comes from.
enum BadgeSourceOrigin {
  /// The `icon` of the flavor.
  flavor,

  /// The `icon` of the root of the configuration.
  root,

  /// The `AppIcon` of the iOS or macOS project.
  project,
}

/// The image a badge is drawn on.
class BadgeSourceIcon {
  /// The path of the image, relative to the root of the project.
  final String path;

  /// Its shorter side, in pixels: [minBadgeSourceSize] at least.
  final int size;

  /// Where the choice found it.
  final BadgeSourceOrigin origin;

  /// Creates a source icon.
  const BadgeSourceIcon({
    required this.path,
    required this.size,
    required this.origin,
  });

  @override
  String toString() => 'BadgeSourceIcon($path, ${size}px, ${origin.name})';
}

/// There is no image of at least [minBadgeSourceSize] pixels to draw a badge on.
class BadgeSourceIconException implements Exception {
  /// What was looked at, in the order of the choice: the paths of the images
  /// that are there but too small, or that are not.
  final List<String> tried;

  /// Creates the exception.
  const BadgeSourceIconException(this.tried);

  @override
  String toString() =>
      'There is no icon of at least $minBadgeSourceSize px to draw the badge '
      'on. Set `icon:` to an image of $minBadgeSourceSize px or more (1024 px '
      'is best).'
      '${tried.isEmpty ? ' No icon was found in the project.' : ' Looked at: ${tried.join(', ')}.'}';
}

/// The iOS and macOS sets that have the icon of the project, in the order they
/// are looked at.
const _projectIconSets = [
  'ios/Runner/Assets.xcassets/AppIcon.appiconset',
  'macos/Runner/Assets.xcassets/AppIcon.appiconset',
];

/// Chooses the image the badge of a flavor is drawn on: the first of these that
/// is [minBadgeSourceSize] pixels or more.
///
/// 1. [flavorIcon], the icon of the flavor;
/// 2. [rootIcon], the `icon` of the root of the configuration;
/// 3. the largest image of the `AppIcon` of the iOS project, then of the macOS
///    one.
///
/// An image that is smaller, or not there, is passed over. When there is none,
/// it fails with a [BadgeSourceIconException] that tells to set `icon:`.
BadgeSourceIcon resolveBadgeSourceIcon({
  String? flavorIcon,
  String? rootIcon,
  required BadgeSourceFiles files,
}) {
  final tried = <String>[];

  BadgeSourceIcon? attempt(String path, BadgeSourceOrigin origin) {
    final size = files.imageSize(path);

    if (size != null && size >= minBadgeSourceSize) {
      return BadgeSourceIcon(path: path, size: size, origin: origin);
    }

    tried.add(path);

    return null;
  }

  for (final (path, origin) in [
    (flavorIcon, BadgeSourceOrigin.flavor),
    (rootIcon, BadgeSourceOrigin.root),
  ]) {
    if (path == null) continue;

    final icon = attempt(path, origin);

    if (icon != null) return icon;
  }

  for (final set in _projectIconSets) {
    for (final path in _imagesOfSet(set, files)) {
      final icon = attempt(path, BadgeSourceOrigin.project);

      if (icon != null) return icon;
    }
  }

  throw BadgeSourceIconException(tried);
}

/// The files of the images of an `.appiconset`, the largest first, as its
/// `Contents.json` lists them. There are none when it has no valid one.
List<String> _imagesOfSet(String set, BadgeSourceFiles files) {
  final text = files.readText(p.posix.join(set, 'Contents.json'));

  if (text == null) return const [];

  final Object? json;

  try {
    json = jsonDecode(text);
  } on FormatException {
    return const [];
  }

  final images = json is Map ? json['images'] : null;

  if (images is! List) return const [];

  final sized = <(double, int, String)>[];

  for (final image in images) {
    if (image is! Map) continue;

    final file = image['filename'];
    final size = _pixels(image['size'], image['scale']);

    if (file is String && size != null) {
      sized.add((size, sized.length, p.posix.join(set, file)));
    }
  }

  // The images of one size stay in the order of the file.
  sized.sort((a, b) {
    final bySize = b.$1.compareTo(a.$1);

    return bySize != 0 ? bySize : a.$2.compareTo(b.$2);
  });

  return [for (final (_, _, path) in sized) path];
}

/// The width in pixels of an image of [size] (`1024x1024`) at [scale] (`2x`).
double? _pixels(Object? size, Object? scale) {
  if (size is! String || scale is! String) return null;

  final points = double.tryParse(size.split('x').first);
  final factor = double.tryParse(scale.replaceAll('x', ''));

  return points == null || factor == null ? null : points * factor;
}
