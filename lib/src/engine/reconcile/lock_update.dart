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
/// record. Its regions and inputs are not rebuilt, since `Artifact` cannot
/// express them yet. The exceptions are the objects and the keys: see
/// [ownedObjects] and [ownedKeys].
///
/// * [produced] are the artifacts each processor tracked, and [ownedHashes] the
///   hash of the owned content of each of them, by canonical path: it must have
///   one for every managed and patched artifact. Local artifacts are never
///   recorded as files (see [ownedKeys] for what a processor may remember of
///   them).
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
/// [ownedKeys] are the keys each processor of the run says it owns
/// (`FlavorizrContext.ownedKeys`), by processor id and then by file: the hash of
/// the value it wrote, by key. They are recorded the way the objects are: what
/// is recorded for a processor is exactly what it says, a file it tracks and
/// said nothing about keeps what the lock had, and so does a file in
/// [retained], where the keys the run meant to write are not. A local file a
/// processor tracks is the exception: it is recorded as the processor says, and
/// it is how the processor remembers the copies it made.
///
/// [written] are the paths the run writes to the project (the changes that
/// are applied, and the conflicts that were approved). A file that several
/// processors patch is hashed as a whole, so the processors that did not run
/// have the hash of what the run wrote in their record of it, but only for the
/// files that are written: a file the run tracked and left as it is still
/// holds what it held, and an edit of it is still an edit for them.
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
  Map<String, Map<String, Map<String, String>>> ownedKeys = const {},
  Set<String> written = const {},
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
    final copies = <String>{};

    for (final artifact in artifacts) {
      final path = canonicalPath(artifact.path);

      if (artifact.ownership == Ownership.local) {
        copies.add(path);
        continue;
      }

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

    final objects = _recordedOf<Set<String>>(
      before: previousProcessors[id]?.objects ?? const {},
      reported: ownedObjects[id] ?? const {},
      files: files.keys.toSet(),
      retained: retained,
      isEmpty: (uuids) => uuids.isEmpty,
    );
    final keys = _recordedOf<Map<String, String>>(
      before: previousProcessors[id]?.keys ?? const {},
      reported: ownedKeys[id] ?? const {},
      files: files.keys.toSet(),
      copies: copies,
      retained: retained,
      isEmpty: (hashes) => hashes.isEmpty,
    );

    if (files.isNotEmpty || objects.isNotEmpty || keys.isNotEmpty) {
      processors[id] = ProcessorLock(
        files: files,
        keys: keys,
        objects: objects,
      );
    }
  }

  _refreshSharedFiles(processors, produced.keys.toSet(), retained, {
    for (final entry in processors.entries)
      if (produced.containsKey(entry.key))
        for (final file in entry.value.files.entries)
          if (file.value.ownership == Ownership.patched &&
              file.value.hash != null &&
              written.contains(file.key) &&
              !retained.contains(file.key))
            file.key: file.value.hash!,
  });

  return FlavorizrLock(
    flavorizrVersion: flavorizrVersion,
    flavors: isFullRun ? desiredFlavors : (previous?.flavors ?? const {}),
    processors: processors,
  );
}

/// What to record for a processor, by file, of what it owns inside the files
/// (the objects of a project, the keys of a file): see `updateLock`.
///
/// What a processor says about a local file it tracks ([copies]) is recorded as
/// it says it, and never carried over: the lock does not hold local files, only
/// what a processor asks it to remember about the copies it made, so that it
/// can tell them from the ones of the user when it stops making them.
Map<String, V> _recordedOf<V>({
  required Map<String, V> before,
  required Map<String, V> reported,
  required Set<String> files,
  required Set<String> retained,
  required bool Function(V value) isEmpty,
  Set<String> copies = const {},
}) {
  final recorded = <String, V>{};

  for (final MapEntry(key: path, value: owned) in before.entries) {
    final canonical = tryCanonicalPath(path);

    if (canonical != null &&
        (files.contains(canonical) || retained.contains(canonical))) {
      recorded[canonical] = owned;
    }
  }

  for (final MapEntry(key: path, value: owned) in reported.entries) {
    final canonical = tryCanonicalPath(path);

    // What a processor says about a file the lock does not record for it is
    // not kept: the file is not owned (not tracked, or kept as the user has it).
    if (canonical == null ||
        retained.contains(canonical) ||
        !(files.contains(canonical) || copies.contains(canonical))) {
      continue;
    }

    recorded[canonical] = owned;
  }

  return {
    for (final entry in recorded.entries)
      if (!isEmpty(entry.value)) entry.key: entry.value,
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

/// A file that several processors patch (the project of Xcode) is hashed as a
/// whole: the hash of each processor's record is the one of what is in the file.
/// So when a run wrote it, the processors that did not run have the hash of what
/// is there now, and not the one of what was there before, which the next run
/// would take for an edit by hand.
///
/// [written] maps each patched file the processors of [ran] recorded to its hash.
/// Only the records of the processors that did not run change, and only for the
/// files they patch too.
void _refreshSharedFiles(
  Map<String, ProcessorLock> processors,
  Set<String> ran,
  Set<String> retained,
  Map<String, String> written,
) {
  if (written.isEmpty) return;

  for (final id in processors.keys.toList()) {
    if (ran.contains(id)) continue;

    final record = processors[id]!;
    final files = {
      for (final entry in record.files.entries)
        entry.key:
            entry.value.ownership == Ownership.patched &&
                written.containsKey(entry.key) &&
                !retained.contains(entry.key)
            ? LockedFile(
                ownership: entry.value.ownership,
                hash: written[entry.key],
              )
            : entry.value,
    };

    if (files.entries.every(
      (entry) => record.files[entry.key] == entry.value,
    )) {
      continue;
    }

    processors[id] = ProcessorLock(
      files: files,
      regions: record.regions,
      keys: record.keys,
      objects: record.objects,
      inputs: record.inputs,
    );
  }
}
