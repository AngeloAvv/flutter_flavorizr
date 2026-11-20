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

import 'package:collection/collection.dart';
import 'package:flutter_flavorizr/src/engine/ownership.dart';

/// The content of `flavorizr.lock`: the memory of what a successful run
/// applied to the project.
///
/// The lock is a plain value. It knows nothing about files or hashing
/// algorithms: hashes are opaque strings computed by the engine, and the
/// serialization lives in `LockCodec`.
final class FlavorizrLock {
  static const _equality = DeepCollectionEquality();

  /// The version of the lock format this flavorizr writes and understands.
  ///
  /// It is bumped whenever the format changes in a way an older flavorizr
  /// cannot read.
  ///
  /// * `1`: the first format, of the 3.0 development builds.
  /// * `2`: a scaffold file may record the hash of what flavorizr wrote (see
  ///   [LockedFile]), and `inputs` is filled in for the generated binaries (see
  ///   [ProcessorLock.inputs]). A lock of version 1 is read as it is, and
  ///   rewritten as version 2 by the next run that writes.
  static const int currentSchemaVersion = 2;

  /// The version of flavorizr that wrote the lock.
  final String flavorizrVersion;

  /// The hash of the resolved configuration of each flavor, by flavor name.
  final Map<String, String> flavors;

  /// The processors that applied artifacts, by processor id.
  final Map<String, ProcessorLock> processors;

  /// Creates a lock written by flavorizr [flavorizrVersion].
  FlavorizrLock({
    required this.flavorizrVersion,
    Map<String, String> flavors = const {},
    Map<String, ProcessorLock> processors = const {},
  }) : flavors = Map.unmodifiable(flavors),
       processors = Map.unmodifiable(processors);

  /// The names of the flavors recorded in the lock, i.e. the value for
  /// `FlavorizrContext.previousFlavors`.
  Set<String> get flavorNames => Set.unmodifiable(flavors.keys);

  @override
  bool operator ==(Object other) =>
      other is FlavorizrLock &&
      other.flavorizrVersion == flavorizrVersion &&
      _equality.equals(other.flavors, flavors) &&
      _equality.equals(other.processors, processors);

  @override
  int get hashCode => Object.hash(
    flavorizrVersion,
    _equality.hash(flavors),
    _equality.hash(processors),
  );

  @override
  String toString() =>
      'FlavorizrLock($flavorizrVersion, flavors: ${flavors.keys.toList()}, '
      'processors: ${processors.keys.toList()})';
}

/// What one processor owns in the project.
final class ProcessorLock {
  static const _equality = DeepCollectionEquality();

  /// The files the processor owns, by path relative to the project root.
  final Map<String, LockedFile> files;

  /// The hash of each marked region the processor owns, by file path and then
  /// region id.
  final Map<String, Map<String, String>> regions;

  /// The hash of each owned key (plist, manifest, XML) the processor owns, by
  /// file path and then key.
  final Map<String, Map<String, String>> keys;

  /// The UUIDs of the pbxproj objects the processor owns, by project file
  /// path.
  final Map<String, Set<String>> objects;

  /// The hash of the *inputs* of each generated binary, such as an icon, by
  /// output path: the hash of the source file and the options, never of the
  /// output, which depends on the version of the libraries that produced it.
  ///
  /// A path is here only when it is also one of [files], and a file whose
  /// inputs and content are what the lock recorded is not rendered again (see
  /// `FlavorizrContext.isGeneratedFrom`).
  final Map<String, String> inputs;

  /// Creates the record of a processor.
  ProcessorLock({
    Map<String, LockedFile> files = const {},
    Map<String, Map<String, String>> regions = const {},
    Map<String, Map<String, String>> keys = const {},
    Map<String, Set<String>> objects = const {},
    Map<String, String> inputs = const {},
  }) : files = Map.unmodifiable(files),
       regions = _freeze(regions),
       keys = _freeze(keys),
       objects = Map<String, Set<String>>.unmodifiable({
         for (final entry in objects.entries)
           entry.key: Set<String>.unmodifiable(entry.value),
       }),
       inputs = Map.unmodifiable(inputs);

  static Map<String, Map<String, String>> _freeze(
    Map<String, Map<String, String>> nested,
  ) => Map<String, Map<String, String>>.unmodifiable({
    for (final entry in nested.entries)
      entry.key: Map<String, String>.unmodifiable(entry.value),
  });

  @override
  bool operator ==(Object other) =>
      other is ProcessorLock &&
      _equality.equals(other.files, files) &&
      _equality.equals(other.regions, regions) &&
      _equality.equals(other.keys, keys) &&
      _equality.equals(other.objects, objects) &&
      _equality.equals(other.inputs, inputs);

  @override
  int get hashCode => Object.hash(
    _equality.hash(files),
    _equality.hash(regions),
    _equality.hash(keys),
    _equality.hash(objects),
    _equality.hash(inputs),
  );
}

/// A file a processor owns, as recorded in the lock.
///
/// The lock records the artifacts of the classes the engine tracks, but never
/// a [Ownership.local] one: it is regenerated silently and is neither drift
/// nor conflict. A hash is recorded for the classes with [Ownership.isHashed],
/// and may be for a scaffold.
final class LockedFile {
  /// The class of the file.
  final Ownership ownership;

  /// The hash of the owned content: the whole file for a managed one, the
  /// owned parts for a patched one.
  ///
  /// For a scaffold it is the hash of what flavorizr wrote, and it is only
  /// there to tell, when the file has to be removed, a file that is as
  /// flavorizr left it from one the user changed: it is `null` for a scaffold
  /// the user had before flavorizr, and for one a lock of version 1 recorded.
  /// Whatever the user does to the file is never drift.
  final String? hash;

  /// Records a file of class [ownership].
  ///
  /// Throws an [ArgumentError] for a local file, and for a hashed class
  /// without [hash].
  LockedFile({required this.ownership, this.hash}) {
    if (ownership == Ownership.local) {
      throw ArgumentError.value(
        ownership,
        'ownership',
        'local artifacts are never stored in the lock',
      );
    }

    if (ownership.isHashed && hash == null) {
      throw ArgumentError.value(
        hash,
        'hash',
        'a ${ownership.name} file needs a hash',
      );
    }
  }

  @override
  bool operator ==(Object other) =>
      other is LockedFile && other.ownership == ownership && other.hash == hash;

  @override
  int get hashCode => Object.hash(ownership, hash);
}
