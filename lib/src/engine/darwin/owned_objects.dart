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
import 'package:flutter_flavorizr/src/engine/artifact.dart';
import 'package:flutter_flavorizr/src/engine/darwin/pbxproj_seed.dart';
import 'package:flutter_flavorizr/src/engine/flavorizr_context.dart';
import 'package:flutter_flavorizr/src/engine/resources/xcodeproj_resource.dart';

/// Makes a new object of [project] with the UUID it is given: `(project, uuid)
/// => XCBuildConfiguration(project, uuid)`.
typedef ObjectFactory<T extends AbstractObject> =
    T Function(XcodeProject project, String uuid);

/// Creates the pbxproj objects a processor owns, finds them again on the next
/// run, and removes the ones nobody wants anymore.
///
/// It is the piece of `XcodeprojResource` consumers share to be idempotent and
/// to leave the project as they found it when what they made is no longer
/// wanted. One instance per processor and project file, for one `FlavorizrProcessor.apply`:
///
/// ```dart
/// final owned = OwnedObjects.ios(ctx);
///
/// for (final flavor in ctx.desiredFlavors.keys) {
///   owned.ensure<XCBuildConfiguration>(
///     (graph, uuid) => XCBuildConfiguration(graph, uuid),
///     flavor: flavor,
///     kind: ['buildConfiguration', 'Debug'],
///     existing: () => list['Debug-$flavor'],
///     create: (config) {
///       config.name = 'Debug-$flavor';
///       list.buildConfigurations.add(config);
///     },
///   );
/// }
///
/// owned.settle(); // removes what the last run created and this one did not
/// ctx.track(XcodeprojResource.iosArtifact);
/// ```
///
/// ## What it guarantees
///
/// * **Deterministic UUIDs.** An object is created with the UUID of its seed
///   (see [PbxprojSeed]), through `XcodeProject.newObject(uuid:)`, so two runs
///   from scratch write the same `project.pbxproj`.
/// * **Idempotence.** [ensure] looks for the object by its UUID first, so a run
///   finds what an earlier one made (also when the lock was lost, since the UUID
///   is the identity), and never creates a second one.
/// * **Foreign objects are never re-keyed, never removed.** An object that
///   exists already, from Flutter, the user or 2.x, is reused as it is when the
///   consumer says how to recognise it ([ensure]'s `existing`), with the UUID it
///   has, and by default it is **not** owned: it is not recorded in the lock and
///   so never removed by [settle]. A consumer that knows an object is
///   flavorizr's (a configuration 2.x created, by its name) can own it with
///   `claimExisting`: the lock then records the UUID it has, which is never
///   rewritten, and [settle] removes it like any other. A UUID that a different
///   kind of object holds is refused.
/// * **Clean removal.** [settle] removes by UUID the objects the lock recorded
///   for the processor and the run did not [ensure], through
///   `AbstractObject.removeFromProject`: it takes the references to the object
///   with it (the entry in a configuration list, in a build phase, the build
///   files of a file reference), so nothing is left dangling.
///
/// ## Objects several owners need
///
/// Ownership belongs to the **object**, not to the seed that made it. An object
/// that flavors may share must be identified by what it is, not by a flavor
/// (see [PbxprojSeed]): a seed with the flavor of the first that asked would
/// make the result depend on which one it was. Flavors
/// that share a file (the same xcconfig) share the one object: the first makes
/// it, the others find it through `existing`. An owned object is kept by
/// [settle] as long as **any** `ensure` of the run returns it, whether it found
/// it by the UUID of its own seed or through `existing` (when the lock recorded
/// it), and it is removed with the last that needed it. So a flavor can be
/// dropped, or renamed, without the objects another one still needs going with
/// it. An object that the consumer **stops** using although it is still there
/// (the xcconfig moved to a file that already has a reference) is simply not
/// returned any more: [settle] removes it. What another processor created is
/// foreign to this one, as it is recorded under that processor: it is used as
/// it is and the lock of the other decides when it goes.
///
/// ## What it cannot do for you
///
/// `dart_xcodeproj` helpers that create objects on their own (`addResources`,
/// `newShellScriptBuildPhase`, `addBuildConfiguration`...) give them a random
/// UUID. For an object that is owned, create it through [ensure] and wire it
/// yourself, in `create`. The `create` callback is for what a **new** object
/// needs (its attributes and where it goes): it does not run for an object that
/// exists, so whatever should be kept in sync on a re-run is the consumer's to
/// do on the object [ensure] returns.
///
/// An object has one owner: two processors must not [ensure] the same seed, as
/// each would [settle] what the other keeps.
final class OwnedObjects {
  /// The context of the processor.
  final FlavorizrContext ctx;

  /// The project, which the processor mutates in memory. It is saved by the
  /// resource, not here.
  final XcodeProject project;

  /// The `project.pbxproj` the objects belong to, the artifact the consumer
  /// tracks.
  final Artifact artifact;

  /// `ios` or `macos`: the platform of the seeds.
  final String platform;

  final Set<String> _owned = {};
  final Set<String> _released = {};

  /// Owns the objects of [project], which `ctx` was given through the resource
  /// of [artifact], for the platform [platform].
  OwnedObjects(
    this.ctx, {
    required this.project,
    required this.artifact,
    required this.platform,
  });

  /// The objects of the iOS project of [ctx], `xcodeproj:ios`.
  factory OwnedObjects.ios(FlavorizrContext ctx) => OwnedObjects(
    ctx,
    project: ctx.resource(XcodeprojResource.iosKey),
    artifact: XcodeprojResource.iosArtifact,
    platform: 'ios',
  );

  /// The objects of the macOS project of [ctx], `xcodeproj:macos`.
  factory OwnedObjects.macos(FlavorizrContext ctx) => OwnedObjects(
    ctx,
    project: ctx.resource(XcodeprojResource.macosKey),
    artifact: XcodeprojResource.macosArtifact,
    platform: 'macos',
  );

  /// Whether the run adopts a project 2.x flavorized (see
  /// `FlavorizrContext.adopting`): the objects 2.x made, which a consumer
  /// recognises by name, are owned with the UUID they have, for the lock to
  /// record it.
  bool get adopting => ctx.adopting;

  /// The UUIDs of the objects [ensure] owned so far in this run.
  Set<String> get owned => Set.unmodifiable(_owned);

  /// The UUID of the object with this identity: see [PbxprojSeed.of].
  String uuidOf({
    String? target,
    String? flavor,
    required Iterable<String> kind,
  }) => PbxprojSeed.uuid(
    platform: platform,
    target: target,
    flavor: flavor,
    kind: kind,
  );

  /// Returns the object with the identity of [target], [flavor] and [kind] (see
  /// [PbxprojSeed.of]), creating it when the project has none.
  ///
  /// In this order:
  ///
  /// 1. the object that has the UUID of the seed is the one: it is owned and
  ///    returned as it is. Throws a [StateError] when it is not a [T];
  /// 2. [existing], if given, looks for an object the consumer recognises (a
  ///    configuration by name, a file by path). It is returned, **keeping its
  ///    UUID**, and handled by [use]: owned when the lock recorded it or
  ///    [claimExisting] is set, foreign (never removed) otherwise;
  /// 3. otherwise [factory] makes a new object with the UUID of the seed and
  ///    [create] fills it and wires it into the project. It is owned.
  ///
  /// [create] runs only for a new object. Throws a [StateError] when it leaves
  /// the object out of the project, which is the sign it was not wired: an
  /// object nothing refers to is not written, and the lock must not record it.
  T ensure<T extends AbstractObject>(
    ObjectFactory<T> factory, {
    String? target,
    String? flavor,
    required Iterable<String> kind,
    T? Function()? existing,
    bool claimExisting = false,
    required void Function(T object) create,
  }) {
    final uuid = uuidOf(target: target, flavor: flavor, kind: kind);
    final found = project.objectsByUuid[uuid];

    if (found != null) {
      if (found is! T) {
        throw StateError(
          'The UUID $uuid, which flavorizr gives to '
          '${PbxprojSeed.of(platform: platform, target: target, flavor: flavor, kind: kind)}, '
          'is held by a ${found.isa}, not a $T: it is not touched.',
        );
      }

      _owned.add(uuid);

      return found;
    }

    final recognised = existing?.call();

    if (recognised != null) {
      return use(recognised, claimExisting: claimExisting);
    }

    final object = project.newObject<T>(
      (_, uuid) => factory(project, uuid),
      uuid: uuid,
    );

    create(object);

    if (!identical(project.objectsByUuid[uuid], object)) {
      throw StateError(
        'The ${object.isa} $uuid was created but not added to the project: '
        '`create` must wire it, or the object is not written.',
      );
    }

    _owned.add(uuid);

    return object;
  }

  /// Says that the run needs [object], which the consumer found on its own
  /// (what [ensure] does with what `existing` returns), and returns it.
  ///
  /// It is owned, and so kept by [settle], when the lock recorded it as created
  /// by this processor (whichever flavor made it) or when [claimExisting] is
  /// set. Any other is foreign: it is used as it is and never removed.
  T use<T extends AbstractObject>(T object, {bool claimExisting = false}) {
    if (claimExisting ||
        ctx.previousObjectsOf(artifact.path).contains(object.uuid)) {
      _owned.add(object.uuid);
    }

    return object;
  }

  /// Gives [object] up: it stays in the project, and [settle] neither removes
  /// it nor records it, so the lock forgets it and it is the user's from now on.
  ///
  /// It is for an object that flavorizr made and does not want anymore but that
  /// holds something that is not flavorizr's, such as a build configuration
  /// the user put a `DEVELOPMENT_TEAM` in. It is never owned again in this run.
  void release(AbstractObject object) {
    _owned.remove(object.uuid);
    _released.add(object.uuid);
  }

  /// Ends the run of the processor on the project, and returns the UUIDs it
  /// removed, sorted.
  ///
  /// It removes, with the cascading `removeFromProject`, every object the lock
  /// recorded for the processor (`FlavorizrContext.previousObjectsOf`) that the
  /// run did not [ensure]: a flavor that was dropped, a phase that is no longer
  /// needed. A recorded object that is not in the project anymore is just
  /// forgotten. The lock is a file the user can edit and merge, so the objects
  /// the project cannot do without are never removed, whatever it lists: the
  /// project, its main group and the targets. It is a warning.
  ///
  /// Then it tells the context what the processor owns now, for the lock to
  /// record. Call it once, after the last [ensure].
  List<String> settle() {
    final stale = ctx
        .previousObjectsOf(artifact.path)
        .difference(_owned)
        .difference(_released);
    final removed = <String>[];

    for (final uuid in stale.toList()..sort()) {
      final object = project.objectsByUuid[uuid];

      if (object == null) continue;

      if (object is PBXProject ||
          object is AbstractTarget ||
          (object is PBXGroup && object.isMainGroup)) {
        ctx.logger.warn(
          'flavorizr.lock lists the ${object.isa} $uuid as created by '
          'flavorizr: it is left in the project.',
        );
        continue;
      }

      removed.add(uuid);
    }

    for (final uuid in removed) {
      // It may be gone already: removing an object takes the ones that only
      // make sense with it (the build files of a file reference).
      project.objectsByUuid[uuid]?.removeFromProject();
    }

    ctx.ownObjects(artifact.path, _owned.difference(_released));

    return removed;
  }
}
