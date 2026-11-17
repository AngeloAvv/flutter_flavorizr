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

import 'package:flutter_flavorizr/src/engine/artifact.dart';
import 'package:flutter_flavorizr/src/engine/lock/flavorizr_lock.dart';
import 'package:flutter_flavorizr/src/engine/ownership.dart';
import 'package:flutter_flavorizr/src/engine/reconcile/stale_artifacts.dart';
import 'package:flutter_flavorizr/src/engine/shadow/workspace_paths.dart';

/// The lock to write after a run that went well.
///
/// Only the processors of the run, the keys of [produced], are rewritten: every
/// other processor keeps exactly the record it had, so a partial run (such as
/// `flavorizr android`) never touches the lock entries of another platform. The
/// record of a processor of the run is rebuilt from what it tracked: the files
/// it stopped producing leave it, and a processor that owns nothing has no
/// record. Its regions, keys, objects and inputs are not rebuilt, since
/// `Artifact` cannot express them yet. The exception are the objects: see
/// [ownedObjects].
///
/// * [produced] are the artifacts each processor tracked, and [ownedHashes] the
///   hash of the owned content of each of them, by canonical path: it must have
///   one for every managed and patched artifact. Local artifacts are never
///   recorded.
/// * [stale] are the files of the processors of the run that were not produced
///   again (see `findStaleArtifacts`).
/// * [retained] are the paths whose file the run left as it was although it
///   meant to write or delete it: the conflicts the user chose to keep, and the
///   deletions that were blocked. Recording the hash of what was *not* written
///   would hide the edit from the next run, so the record the lock had is
///   carried over instead, and a file the lock did not know is not recorded.
///
/// [ownedObjects] are the UUIDs of the pbxproj objects each processor of the run
/// says it owns (`FlavorizrContext.ownedObjects`), by processor id and then by
/// project file. What is recorded for a processor is exactly what it says, so an
/// object it no longer owns leaves the lock. Two cases keep what the lock had
/// instead, so that nothing a processor owns is ever forgotten: a file it
/// tracks and said nothing about, and a file in [retained], which the run did
/// not write: the objects it created there are not in the project. A file the
/// processor stopped tracking takes its objects with it.
///
/// [desiredFlavors] maps each flavor to the hash of its resolved configuration.
/// It is recorded only when the run covers every one of [availableProcessors]:
/// the flavors the lock records are the ones every processor applied, and a
/// partial run says nothing about the processors it did not run.
FlavorizrLock updateLock({
  required FlavorizrLock? previous,
  required String flavorizrVersion,
  required Map<String, Iterable<Artifact>> produced,
  required Map<String, String> ownedHashes,
  required Map<String, String> desiredFlavors,
  required Set<String> availableProcessors,
  Iterable<StaleArtifact> stale = const [],
  Set<String> retained = const {},
  Map<String, Map<String, Set<String>>> ownedObjects = const {},
}) {
  final previousProcessors = previous?.processors ?? const {};
  final isFullRun =
      availableProcessors.isNotEmpty &&
      availableProcessors.every(produced.containsKey);
  final processors = {...previousProcessors}
    ..removeWhere((id, _) => produced.containsKey(id));

  for (final MapEntry(key: id, value: artifacts) in produced.entries) {
    final before = previousProcessors[id]?.files ?? const {};
    final files = <String, LockedFile>{};

    for (final artifact in artifacts) {
      if (artifact.ownership == Ownership.local) continue;

      final path = canonicalPath(artifact.path);

      if (retained.contains(path)) {
        final recorded = _sameClass(before[path], artifact.ownership);

        if (recorded != null) files[path] = recorded;
        continue;
      }

      files[path] = LockedFile(
        ownership: artifact.ownership,
        hash: artifact.ownership.isHashed ? _hashOf(ownedHashes, path) : null,
      );
    }

    for (final entry in stale) {
      if (entry.processorId == id &&
          retained.contains(entry.path) &&
          !files.containsKey(entry.path)) {
        files[entry.path] = LockedFile(
          ownership: entry.ownership,
          hash: entry.recordedHash,
        );
      }
    }

    final objects = _objectsOf(
      before: previousProcessors[id]?.objects ?? const {},
      reported: ownedObjects[id] ?? const {},
      files: files.keys.toSet(),
      retained: retained,
    );

    if (files.isNotEmpty || objects.isNotEmpty) {
      processors[id] = ProcessorLock(files: files, objects: objects);
    }
  }

  return FlavorizrLock(
    flavorizrVersion: flavorizrVersion,
    flavors: isFullRun ? desiredFlavors : (previous?.flavors ?? const {}),
    processors: processors,
  );
}

/// The objects to record for a processor: see `updateLock`.
Map<String, Set<String>> _objectsOf({
  required Map<String, Set<String>> before,
  required Map<String, Set<String>> reported,
  required Set<String> files,
  required Set<String> retained,
}) {
  final recorded = <String, Set<String>>{};

  for (final MapEntry(key: path, value: uuids) in before.entries) {
    final canonical = tryCanonicalPath(path);

    if (canonical != null &&
        (files.contains(canonical) || retained.contains(canonical))) {
      recorded[canonical] = uuids;
    }
  }

  for (final MapEntry(key: path, value: uuids) in reported.entries) {
    final canonical = tryCanonicalPath(path);

    // What a processor says about a file the lock does not record for it is
    // not kept: the file is not owned (not tracked, or kept as the user has it).
    if (canonical == null ||
        retained.contains(canonical) ||
        !files.contains(canonical)) {
      continue;
    }

    recorded[canonical] = uuids;
  }

  return {
    for (final entry in recorded.entries)
      if (entry.value.isNotEmpty) entry.key: entry.value,
  };
}

LockedFile? _sameClass(LockedFile? recorded, Ownership ownership) =>
    recorded != null && recorded.ownership == ownership ? recorded : null;

String _hashOf(Map<String, String> ownedHashes, String path) {
  final hash = ownedHashes[path];

  if (hash == null) {
    throw ArgumentError.value(
      path,
      'ownedHashes',
      'a hashed artifact needs the hash of its owned content',
    );
  }

  return hash;
}
