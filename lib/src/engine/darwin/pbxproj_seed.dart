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

import 'package:dart_xcodeproj/dart_xcodeproj.dart';

/// The seeds, and so the UUIDs, of the pbxproj objects flavorizr creates.
///
/// 2.x gave every object it created a random UUID, so each run left a diff in
/// `project.pbxproj` and an object could not be found again to be removed. An
/// object flavorizr creates now gets a UUID derived from **what it is**:
///
/// ```text
/// flavorizr/<platform>/<target>/<flavor>/<kind>[/<detail>...]
/// ```
///
/// | Segment | Meaning |
/// | --- | --- |
/// | `<platform>` | `ios` or `macos`. |
/// | `<target>` | The name of the target the object belongs to, such as `Runner`; `@project` for an object of the project itself (its build configurations, for instance). |
/// | `<flavor>` | The name of the flavor; `@all` for an object that does not belong to a flavor (a build phase shared by all of them). |
/// | `<kind>` and `<detail>` | What the object is and which one, such as `buildConfiguration/Debug` (the `Debug` configuration of the flavor) or `fileReference/Debug` . |
///
/// So `flavorizr/ios/@project/dev/buildConfiguration/Debug` is the `Debug-dev`
/// configuration of the project of iOS, and it is the same on every machine and
/// every run. The UUID is the first 24 hex characters of the MD5 of the seed
/// (`UuidGenerator.deterministic`), which looks like the ones Xcode writes.
///
/// An object that several flavors may share (the reference to an xcconfig file
/// two of them use) is identified by **what it is**, not by the flavor that
/// happened to ask first: it takes `@all` for the flavor and a kind that names
/// it, such as `fileReference/Flutter/shared.xcconfig`, one segment per part of
/// the path. Then it is the same object for every flavor that asks for it,
/// whatever order they are processed in, and a flavor that moves to another path
/// asks for another object instead of changing the shared one.
///
/// A segment holds no `/`, so that two different seeds can never spell the same
/// path, and `@` is reserved to the two markers above: a target or a flavor
/// cannot start by it. Truncating the digest makes a clash a little more
/// likely than the full MD5 would, which is why the seed names the platform, the
/// target and the flavor: a UUID that is taken by an object flavorizr did not
/// create is refused, never reused (see `OwnedObjects.ensure`).
///
/// The UUID of an object that already exists is **never** rewritten: this is
/// for the objects flavorizr creates, not for the project as a whole (which is
/// why `XcodeProject.predictabilizeUuids` is not used: it would change the UUIDs
/// of Flutter's and the user's objects, and break what refers to them from
/// outside of the file, such as the `BlueprintIdentifier` of a scheme).
abstract final class PbxprojSeed {
  /// The target segment of an object that belongs to the project itself.
  static const projectTarget = '@project';

  /// The flavor segment of an object that does not belong to a flavor.
  static const allFlavors = '@all';

  static const _platforms = {'ios', 'macos'};

  /// The seed of an object: see the class documentation.
  ///
  /// A `null` [target] is the project, and a `null` [flavor] is every flavor.
  /// Throws an [ArgumentError] when [platform] is not `ios` or `macos`, when
  /// [kind] is empty, and when a segment is empty, holds a `/` or a `\`, or (for
  /// [target] and [flavor]) starts by the reserved `@`.
  static String of({
    required String platform,
    String? target,
    String? flavor,
    required Iterable<String> kind,
  }) {
    final details = kind.toList();

    if (!_platforms.contains(platform)) {
      throw ArgumentError.value(
        platform,
        'platform',
        'must be one of ${_platforms.join(', ')}',
      );
    }

    if (details.isEmpty) {
      throw ArgumentError.value(kind, 'kind', 'must name what the object is');
    }

    return [
      'flavorizr',
      platform,
      target == null ? projectTarget : _segment(target, 'target', named: true),
      flavor == null ? allFlavors : _segment(flavor, 'flavor', named: true),
      for (final detail in details) _segment(detail, 'kind'),
    ].join('/');
  }

  /// The UUID of the object whose seed is [of], 24 uppercase hex characters.
  static String uuid({
    required String platform,
    String? target,
    String? flavor,
    required Iterable<String> kind,
  }) => UuidGenerator.deterministic(
    of(platform: platform, target: target, flavor: flavor, kind: kind),
  );

  static String _segment(String value, String name, {bool named = false}) {
    if (value.isEmpty || value.contains('/') || value.contains(r'\')) {
      throw ArgumentError.value(
        value,
        name,
        'must not be empty nor hold a path separator',
      );
    }

    if (named && value.startsWith('@')) {
      throw ArgumentError.value(value, name, 'must not start by `@`');
    }

    return value;
  }
}
