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

/// The app icon a flavor of iOS or macOS builds with.
///
/// A flavor that has an `icon`, or has an `AppIcon-<flavor>.appiconset` that
/// is already in the project, builds with that set. Any other flavor builds
/// with the `AppIcon` of the project, so flavorizr makes no icon for it. A
/// build setting the user wrote, even one that spells the default, is never
/// changed.
abstract final class DarwinIconName {
  /// The build setting that names the app icon.
  static const setting = 'ASSETCATALOG_COMPILER_APPICON_NAME';

  /// The set every flavor builds with unless it has one of its own.
  static const projectDefault = 'AppIcon';

  /// The set of a flavor, as the default build settings spell it.
  static const flavorSet = r'AppIcon-$(ASSET_PREFIX)';

  /// [settings] with the icon of the flavor [flavorName]: the set of the flavor
  /// when [hasIcon] or when [assetsPath] has it, [projectDefault] if not.
  /// [chosen] is whether the user wrote the setting: it is left as it is.
  static Map<String, dynamic> resolve(
    Map<String, dynamic> settings, {
    required String assetsPath,
    required String flavorName,
    required bool hasIcon,
    bool chosen = false,
  }) {
    if (chosen || settings[setting] != flavorSet) return settings;

    final exists = Directory(
      '$assetsPath/AppIcon-$flavorName.appiconset',
    ).existsSync();

    return hasIcon || exists ? settings : {...settings, setting: projectDefault};
  }
}
