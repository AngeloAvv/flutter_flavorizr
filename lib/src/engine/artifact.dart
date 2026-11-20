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

/// Something a processor owns in the project and declares through
/// `FlavorizrContext.track`.
///
/// Every artifact has an [ownership] class, chosen when it is created: there is
/// no way to build an artifact without one, so a processor cannot track a file
/// without saying who owns it. Create artifacts through the named factories,
/// which can be `const`:
///
/// ```dart
/// ctx.track(const Artifact.managed('lib/flavors.dart'));
/// ```
///
/// The type is `sealed`, so a `switch` over an artifact is checked for
/// exhaustiveness.
sealed class Artifact {
  /// The path of the artifact, relative to the project root.
  final String path;

  const Artifact._(this.path);

  /// An artifact created once and never overwritten afterwards.
  /// See [Ownership.scaffold].
  const factory Artifact.scaffold(String path) = ScaffoldArtifact;

  /// An artifact fully regenerated and hashed in the lock.
  /// See [Ownership.managed].
  ///
  /// A file generated from inputs that are costly to turn into the same bytes
  /// on every machine (an icon rendered from an image) declares [inputs], the
  /// hash of everything it is made from: see [ManagedArtifact.inputs].
  const factory Artifact.managed(String path, {String? inputs}) =
      ManagedArtifact;

  /// An artifact of which only the owned parts are touched and hashed.
  /// See [Ownership.patched].
  const factory Artifact.patched(String path) = PatchedArtifact;

  /// An artifact regenerated silently and never hashed.
  /// See [Ownership.local].
  const factory Artifact.local(String path) = LocalArtifact;

  /// The class of the artifact, which decides what a run may do to it.
  Ownership get ownership;

  /// The hash of everything the artifact is generated from, or `null`.
  ///
  /// Only a [ManagedArtifact] has it. See [ManagedArtifact.inputs].
  String? get inputs => null;

  @override
  bool operator ==(Object other) =>
      other is Artifact &&
      other.runtimeType == runtimeType &&
      other.path == path &&
      other.inputs == inputs;

  @override
  int get hashCode => Object.hash(runtimeType, path, inputs);

  @override
  String toString() =>
      'Artifact.${ownership.name}($path${inputs == null ? '' : ', inputs: $inputs'})';
}

/// An artifact of class [Ownership.scaffold].
final class ScaffoldArtifact extends Artifact {
  /// Creates a scaffold artifact living at [path].
  const ScaffoldArtifact(super.path) : super._();

  @override
  Ownership get ownership => Ownership.scaffold;
}

/// An artifact of class [Ownership.managed].
final class ManagedArtifact extends Artifact {
  /// The hash of everything the file is generated from, such as the bytes of
  /// the source image of an icon and the options it is rendered with, or `null`
  /// for a file that is cheap and deterministic to generate.
  ///
  /// It is recorded in the lock next to the hash of the file. A later run asks
  /// the context whether the file is still what was generated from the same
  /// inputs (`FlavorizrContext.isGeneratedFrom`) and, if so, leaves it as it is
  /// instead of rendering it again: a library that renders the same inputs to
  /// other bytes on another machine, or in another version, then changes
  /// nothing.
  ///
  /// It must be computed from the inputs alone, never from the output, and must
  /// not depend on the machine, so that it is the same everywhere.
  @override
  final String? inputs;

  /// Creates a managed artifact living at [path].
  const ManagedArtifact(super.path, {this.inputs})
    : assert(inputs == null || inputs != ''),
      super._();

  @override
  Ownership get ownership => Ownership.managed;
}

/// An artifact of class [Ownership.patched].
final class PatchedArtifact extends Artifact {
  /// Creates a patched artifact living at [path].
  const PatchedArtifact(super.path) : super._();

  @override
  Ownership get ownership => Ownership.patched;
}

/// An artifact of class [Ownership.local].
final class LocalArtifact extends Artifact {
  /// Creates a local artifact living at [path].
  const LocalArtifact(super.path) : super._();

  @override
  Ownership get ownership => Ownership.local;
}
