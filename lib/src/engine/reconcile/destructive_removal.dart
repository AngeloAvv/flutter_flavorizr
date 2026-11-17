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

import 'package:flutter_flavorizr/src/engine/lock/flavorizr_lock.dart';
import 'package:flutter_flavorizr/src/exception/last_flavor_removal_exception.dart';
import 'package:flutter_flavorizr/src/exception/platform_drop_exception.dart';

/// The platforms a processor id can start with, e.g. `android` for
/// `android:icons`. The other prefixes (`flutter`, `ide`, ...) are not a
/// platform: nothing is un-flavorized there.
const _platforms = {'android', 'ios', 'macos', 'linux', 'windows'};

/// Refuses a configuration that asks for what flavorizr cannot do: to undo its
/// own changes.
///
/// The values flavorizr owns overwrite the original ones (`android:label`,
/// `CFBundleName`) and the originals are not stored, so removing the last
/// flavor, or every flavor of a platform, would leave the project half
/// flavorized. Un-flavorizing is out of scope for 3.0, and the run stops before
/// anything is written.
///
/// [previous] is the lock of the project: only what it records is checked, so a
/// project that was never applied, or a platform that was never recorded, is
/// never refused. [flavors] are the names of the flavors of the configuration
/// and [platforms] the platforms that have at least one of them.
///
/// Throws a [LastFlavorRemovalException] when the lock records flavors and
/// [flavors] is empty, and otherwise a [PlatformDropException] when the lock
/// records files of a platform that is not in [platforms]. Removing flavors
/// down to one is always fine.
void checkRemoval({
  required FlavorizrLock? previous,
  required Set<String> flavors,
  required Set<String> platforms,
}) {
  if (previous == null) return;

  if (flavors.isEmpty && previous.flavors.isNotEmpty) {
    throw LastFlavorRemovalException(previous.flavorNames);
  }

  final dropped = <String, Set<String>>{};

  for (final MapEntry(key: id, value: record) in previous.processors.entries) {
    final platform = id.split(':').first;

    if (!_platforms.contains(platform) || platforms.contains(platform)) {
      continue;
    }

    dropped.putIfAbsent(platform, () => {}).addAll(_pathsOf(record));
  }

  dropped.removeWhere((_, paths) => paths.isEmpty);

  if (dropped.isNotEmpty) throw PlatformDropException(dropped);
}

Iterable<String> _pathsOf(ProcessorLock record) => {
  ...record.files.keys,
  ...record.regions.keys,
  ...record.keys.keys,
  ...record.objects.keys,
  ...record.inputs.keys,
};
