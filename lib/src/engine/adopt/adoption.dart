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

import 'package:flutter_flavorizr/src/engine/adopt/dummy_assets.dart';
import 'package:flutter_flavorizr/src/engine/artifact.dart';
import 'package:flutter_flavorizr/src/engine/lock/flavorizr_lock.dart';
import 'package:flutter_flavorizr/src/engine/ownership.dart';
import 'package:flutter_flavorizr/src/engine/reconcile/lock_update.dart';
import 'package:flutter_flavorizr/src/engine/shadow/workspace_diff.dart';
import 'package:flutter_flavorizr/src/engine/shadow/workspace_paths.dart';

/// The processor that makes the launcher icons of Android, which is the one the
/// dummy icons of 2.x are recorded for.
const androidIconsProcessorId = 'android:icons';

/// What adopting a project 2.x flavorized records.
final class Adoption {
  /// The lock to write: the baseline.
  final FlavorizrLock lock;

  /// The files recorded, by processor id and sorted by path.
  final Map<String, List<String>> recorded;

  /// The files 2.x would have put there, which are not the ones it wrote: the
  /// user replaced them. They are not recorded, so no run deletes or
  /// overwrites them.
  final List<String> userOwned;

  /// Creates what was adopted.
  Adoption({
    required this.lock,
    required Map<String, List<String>> recorded,
    required List<String> userOwned,
  }) : recorded = Map.unmodifiable({
         for (final entry in recorded.entries)
           entry.key: List<String>.unmodifiable(entry.value),
       }),
       userOwned = List.unmodifiable(userOwned);
}

/// Records the project as it is, as the baseline of the lock, without writing to
/// it.
///
/// A project flavorized by 2.x has no lock, and what flavorizr would change in
/// it is told by the difference between what a run produces and what the lock
/// recorded for it. The baseline is therefore what the *disk* holds: for each
/// file the processors of the run [produced] that the project has, the hash of
/// the part flavorizr owns (the whole file, or what [hasher] reads of a patched
/// one), so that the next `plan` shows the 3.0 output as an ordinary change to
/// it, and never a conflict. A file the project does not have is not recorded:
/// it is just created. A scaffold file is the user's, and a local one is never
/// in the lock: neither is recorded.
///
/// What 3.0 no longer makes cannot be found in [produced]. The dummy icons of 2.x
/// for the flavors in [androidFlavors] (which may name flavors the configuration
/// no longer has) are looked for by hash (see [DummyAssets]): the ones still
/// holding the bytes 2.x wrote are recorded as managed by the icons processor,
/// which no longer makes them, so that the next run proposes to delete them. The
/// ones with other bytes are the user's, and are only reported. This is done only
/// when the icons processor is part of [produced].
///
/// [flavors] maps each flavor to what the lock records for it, and
/// [availableProcessors] are the processors a full run covers: like any run, the
/// adoption records the flavors only when it covers all of them.
Future<Adoption> adoptProject({
  required Directory projectRoot,
  required Map<String, Iterable<Artifact>> produced,
  required Iterable<String> androidFlavors,
  required Map<String, String> flavors,
  required Set<String> availableProcessors,
  required String flavorizrVersion,
  required ArtifactHasher hasher,
  DummyAssets? dummyAssets,
}) async {
  final present = <String, List<Artifact>>{};
  final hashes = <String, String>{};

  for (final MapEntry(key: id, value: artifacts) in produced.entries) {
    final found = present.putIfAbsent(id, () => []);

    for (final artifact in artifacts) {
      if (artifact.ownership == Ownership.local ||
          artifact.ownership == Ownership.scaffold) {
        continue;
      }

      final path = tryCanonicalPath(artifact.path);
      final bytes = path == null ? null : _read(projectRoot, path);

      if (path == null || bytes == null) continue;

      found.add(artifact);
      hashes[path] = hasher(artifact, bytes);
    }
  }

  final userOwned = <String>[];

  if (present.containsKey(androidIconsProcessorId)) {
    for (final flavor in androidFlavors.where(_isFolderName)) {
      final dummies = (dummyAssets ?? DummyAssets.v2).flavorPaths(
        flavor,
        platform: 'android',
      );

      for (final MapEntry(key: path, value: expected) in dummies.entries) {
        final bytes = hashes.containsKey(path)
            ? null
            : _read(projectRoot, path);

        if (bytes == null) continue;

        if (DummyAssets.hashOf(bytes) == expected) {
          final artifact = Artifact.managed(path);

          present[androidIconsProcessorId]!.add(artifact);
          hashes[path] = hasher(artifact, bytes);
        } else {
          userOwned.add(path);
        }
      }
    }
  }

  final lock = updateLock(
    previous: null,
    flavorizrVersion: flavorizrVersion,
    produced: present,
    ownedHashes: hashes,
    desiredFlavors: flavors,
    availableProcessors: availableProcessors,
  );

  return Adoption(
    lock: lock,
    recorded: {
      for (final MapEntry(key: id, value: processor) in lock.processors.entries)
        id: processor.files.keys.toList()..sort(),
    },
    userOwned: userOwned..sort(),
  );
}

/// What the file at [path] holds, or `null` when the project has no file there,
/// or the path goes through a link: a link is never followed, as anywhere in
/// the engine.
List<int>? _read(Directory projectRoot, String path) {
  final resolved = resolveIn(projectRoot, path);

  if (goesThroughLink(projectRoot, path) ||
      FileSystemEntity.typeSync(resolved, followLinks: false) !=
          FileSystemEntityType.file) {
    return null;
  }

  return File(resolved).readAsBytesSync();
}

/// Whether [name] is a single segment of a path, and so is safe to look for
/// below a folder.
bool _isFolderName(String name) =>
    name.isNotEmpty &&
    name != '.' &&
    name != '..' &&
    !name.contains(RegExp(r'[/\\\x00]'));
