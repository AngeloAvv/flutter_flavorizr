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
import 'package:flutter_flavorizr/src/engine/shadow/workspace_paths.dart';

/// A file the lock attributes to a processor that ran, and which that
/// processor did not produce again: a candidate for garbage collection.
final class StaleArtifact {
  /// The id of the processor the lock attributes the file to.
  final String processorId;

  /// The canonical path of the file, relative to the project.
  final String path;

  /// The class the lock recorded for the file.
  final Ownership ownership;

  /// The hash the lock recorded for the file, `null` for a scaffold: the lock
  /// never hashes it.
  final String? recordedHash;

  /// Creates a stale artifact.
  const StaleArtifact({
    required this.processorId,
    required this.path,
    required this.ownership,
    required this.recordedHash,
  });

  @override
  String toString() => 'StaleArtifact($processorId, ${ownership.name}, $path)';
}

/// A path of the lock that cannot be a file of the project, such as one that
/// leaves it: the lock is edited by merges and by hand, so it is not trusted.
final class InvalidLockedPath {
  /// The id of the processor the lock attributes the path to.
  final String processorId;

  /// The path, as written in the lock.
  final String path;

  /// Why the path is not valid.
  final String reason;

  /// Creates an invalid path.
  const InvalidLockedPath({
    required this.processorId,
    required this.path,
    required this.reason,
  });

  @override
  String toString() => 'InvalidLockedPath($processorId, $path: $reason)';
}

/// What [findStaleArtifacts] found.
final class StaleScan {
  /// The stale files, sorted by processor and path.
  final List<StaleArtifact> stale;

  /// The paths of the lock that are not valid, and are therefore never
  /// deleted.
  final List<InvalidLockedPath> invalid;

  /// The files the lock attributes to a processor that ran, which the run
  /// tracked without attributing them to any processor (e.g. from the teardown
  /// of a resource). They are not stale, since the run still owns them, and the
  /// lock keeps what it had for them, as nobody can say whose they are now.
  final List<StaleArtifact> unattributed;

  /// Creates a scan.
  StaleScan({
    required Iterable<StaleArtifact> stale,
    required Iterable<InvalidLockedPath> invalid,
    Iterable<StaleArtifact> unattributed = const [],
  }) : stale = List.unmodifiable(stale),
       invalid = List.unmodifiable(invalid),
       unattributed = List.unmodifiable(unattributed);
}

/// Finds the files that the [previous] lock attributes to a processor that ran
/// in this run, and that the processor did not [produced] again.
///
/// [produced] holds the artifacts of every processor that ran, by processor id:
/// its keys are the scope of the run, and a processor that ran and tracked
/// nothing maps to an empty list. The lock entries of any other processor are
/// never looked at, so a partial run cannot reach what it did not run.
///
/// [tracked] is every artifact the run tracked, whoever it is attributed to
/// (`FlavorizrContext.tracked`): it is the ownership view of the context, and a
/// tracked path is never stale, even when no processor produced it (see
/// [StaleScan.unattributed]).
///
/// A file is stale only when nobody owns it anymore: a path the run tracks, or
/// that a processor that did not run still owns in the lock (a file, a region,
/// a key or an object), is not.
StaleScan findStaleArtifacts({
  required FlavorizrLock? previous,
  required Map<String, Iterable<Artifact>> produced,
  required Iterable<Artifact> tracked,
}) {
  final stale = <StaleArtifact>[];
  final invalid = <InvalidLockedPath>[];
  final unattributed = <StaleArtifact>[];

  if (previous == null) return StaleScan(stale: stale, invalid: invalid);

  final producedPaths = <String>{
    for (final artifacts in produced.values)
      for (final artifact in artifacts)
        pathIdentity(canonicalPath(artifact.path)),
  };
  final trackedPaths = <String>{
    for (final artifact in tracked) pathIdentity(canonicalPath(artifact.path)),
  };
  final keptByOthers = <String>{
    for (final MapEntry(key: id, value: lock) in previous.processors.entries)
      if (!produced.containsKey(id)) ..._pathsOf(lock),
  };

  for (final MapEntry(key: id, value: lock) in previous.processors.entries) {
    if (!produced.containsKey(id)) continue;

    for (final MapEntry(key: path, value: file) in lock.files.entries) {
      final String canonical;

      try {
        canonical = canonicalPath(path);
      } on ArgumentError catch (error) {
        invalid.add(
          InvalidLockedPath(
            processorId: id,
            path: path,
            reason: '${error.message}',
          ),
        );
        continue;
      }

      if (producedPaths.contains(pathIdentity(canonical)) ||
          keptByOthers.contains(pathIdentity(canonical))) {
        continue;
      }

      final record = StaleArtifact(
        processorId: id,
        path: canonical,
        ownership: file.ownership,
        recordedHash: file.hash,
      );

      (trackedPaths.contains(pathIdentity(canonical)) ? unattributed : stale)
          .add(record);
    }
  }

  return StaleScan(
    stale: stale..sort(_byProcessorThenPath),
    unattributed: unattributed..sort(_byProcessorThenPath),
    invalid: invalid
      ..sort((a, b) => _compare(a.processorId, a.path, b.processorId, b.path)),
  );
}

int _byProcessorThenPath(StaleArtifact a, StaleArtifact b) =>
    _compare(a.processorId, a.path, b.processorId, b.path);

int _compare(String idA, String pathA, String idB, String pathB) {
  final byId = idA.compareTo(idB);

  return byId != 0 ? byId : pathA.compareTo(pathB);
}

/// Every path the lock of one processor refers to, in canonical form. Paths
/// that cannot be canonicalised are skipped: they can never match a real file.
Iterable<String> _pathsOf(ProcessorLock lock) sync* {
  for (final path in [
    ...lock.files.keys,
    ...lock.regions.keys,
    ...lock.keys.keys,
    ...lock.objects.keys,
    ...lock.inputs.keys,
  ]) {
    try {
      yield pathIdentity(canonicalPath(path));
    } on ArgumentError {
      continue;
    }
  }
}

/// How paths are compared: ignoring case. On a case-insensitive filesystem
/// (macOS, Windows) `Lib/A.dart` and `lib/a.dart` are one file, and deleting the
/// old spelling would delete what the run just wrote. On a case-sensitive one
/// the cost is a stale file that stays until it is removed by hand.
String pathIdentity(String path) => path.toLowerCase();
