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

import 'package:flutter_flavorizr/src/engine/ownership.dart';

/// What a run must do with an artifact, as decided by [decideArtifactAction].
enum ArtifactAction {
  /// Write the artifact: the file does not exist yet.
  create,

  /// Replace the whole file with the desired content.
  overwrite,

  /// Rewrite only the owned parts of the file, preserving the rest.
  patch,

  /// Leave the file alone: nothing to do.
  skip,

  /// The file was changed by hand and the run would lose those changes, so it
  /// must not be written without the user's say.
  conflict,
}

/// What is known about an artifact when a run decides what to do with it.
///
/// A hash identifies the content of the *owned* part of the file: the whole
/// file for managed artifacts, the marked regions or owned keys for patched
/// ones. Computing it is up to the caller; the rules only compare hashes.
class ArtifactState {
  /// Whether the file exists in the project.
  final bool exists;

  /// The hash of the owned content found in the project now, or `null` when
  /// the file does not exist.
  final String? currentHash;

  /// The hash the lock recorded at the previous run, or `null` when the
  /// artifact is not in the lock.
  final String? recordedHash;

  /// The hash of the content the run wants to produce.
  final String desiredHash;

  /// The state of a file that does not exist.
  const ArtifactState.missing({this.recordedHash, required this.desiredHash})
    : exists = false,
      currentHash = null;

  /// The state of a file that exists with content hashing to [currentHash].
  const ArtifactState.existing({
    required String this.currentHash,
    this.recordedHash,
    required this.desiredHash,
  }) : exists = true;
}

/// Decides what a run must do with an artifact of class [ownership] in the
/// given [state].
///
/// It is a pure function: it reads no file and computes no hash. See
/// [Ownership] for the guarantee of each class. [overwriteScaffold] is the
/// `--overwrite-scaffold` flag and only matters for scaffold artifacts.
ArtifactAction decideArtifactAction(
  Ownership ownership,
  ArtifactState state, {
  bool overwriteScaffold = false,
}) {
  switch (ownership) {
    case Ownership.scaffold:
      if (!state.exists) {
        return ArtifactAction.create;
      }

      return overwriteScaffold ? ArtifactAction.overwrite : ArtifactAction.skip;
    case Ownership.managed:
      return _decideHashed(state, ArtifactAction.overwrite);
    case Ownership.patched:
      return _decideHashed(state, ArtifactAction.patch);
    case Ownership.local:
      // Hashes are ignored on purpose: a build may have changed the file, and
      // that is neither drift nor a conflict.
      return state.exists ? ArtifactAction.overwrite : ArtifactAction.create;
  }
}

/// The rule of the hashed classes, which differ only in how they write.
ArtifactAction _decideHashed(ArtifactState state, ArtifactAction write) {
  if (!state.exists) {
    return ArtifactAction.create;
  }

  if (state.currentHash == state.desiredHash) {
    return ArtifactAction.skip;
  }

  // The owned content is untouched since the last run only when the lock
  // knows it: without a record there is no telling a stale file from an edit.
  final untouched =
      state.recordedHash != null && state.currentHash == state.recordedHash;

  return untouched ? write : ArtifactAction.conflict;
}
