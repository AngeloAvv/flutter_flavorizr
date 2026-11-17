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

import 'package:collection/collection.dart';
import 'package:dart_xcodeproj/dart_xcodeproj.dart';
import 'package:flutter_flavorizr/src/engine/artifact.dart';
import 'package:flutter_flavorizr/src/engine/flavorizr_context.dart';
import 'package:flutter_flavorizr/src/engine/resource.dart';
import 'package:flutter_flavorizr/src/engine/resource_key.dart';
import 'package:flutter_flavorizr/src/exception/file_not_found_exception.dart';
import 'package:path/path.dart' as p;

/// Opens the `.xcodeproj` bundle at [path], which is absolute.
typedef XcodeprojOpener = Future<XcodeProject> Function(String path);

/// Writes [project] to disk.
typedef XcodeprojSaver = Future<void> Function(XcodeProject project);

/// The Xcode project of a platform, opened once and shared by every processor
/// that mutates it: `xcodeproj:ios` and `xcodeproj:macos`.
///
/// The 2.x Darwin processors each opened and saved `project.pbxproj` on their
/// own. With this resource the engine does it once per run:
///
/// * [setup] opens `<platform>/Runner.xcodeproj` of the shadow workspace
///   ([FlavorizrContext.root]) right before the first processor that requires
///   it, and remembers how the project looked.
/// * Every consumer reads the same [XcodeProject] through
///   [FlavorizrContext.resource] and mutates it in memory. It never calls
///   `save`, nor opens the project itself.
/// * [teardown] saves the project once, right after the last consumer, only
///   when the run succeeded so far **and** the project is different from what
///   was opened. Otherwise `project.pbxproj` is not touched: a run with no
///   change leaves it byte identical, and a failed run saves nothing.
///
/// Everything happens in the shadow workspace, so a dry run (`plan`) writes
/// nothing to the project; what the run changed reaches the project through
/// the usual diff, conflict check and copy back.
///
/// ## Writing a processor on top of it
///
/// ```dart
/// class IosSomethingProcessor extends FlavorizrProcessor {
///   @override
///   Set<ResourceKey<Object?>> get requires => {XcodeprojResource.iosKey};
///
///   @override
///   Future<void> apply(FlavorizrContext ctx) async {
///     final project = ctx.resource(XcodeprojResource.iosKey);
///
///     // ... mutate [project], idempotently ...
///
///     ctx.track(XcodeprojResource.iosArtifact);
///   }
/// }
/// ```
///
/// and register it with the folder of the project among its paths, so that the
/// shadow workspace holds it: `paths: {XcodeprojResource.iosProject}` (the
/// registry adds it by itself for the resources a processor requires).
///
/// Rules for consumers:
///
/// * **Be idempotent.** Look for what you want before creating it: whatever
///   the run leaves equal to the project it opened is not saved. Mutations are
///   compared by value, in order, so setting a key to the value it has, or
///   undoing a change within the run, is no change.
/// * **Track the project file.** The shadow workspace never copies back a file
///   nobody tracked: declare [iosArtifact] or [macosArtifact] (patched, since
///   the user and Flutter own the rest of the project) even when the processor
///   happens to change nothing.
/// * **Do not keep the project** after [FlavorizrProcessor.apply] returns, and
///   do not save it: the resource does, last.
/// * **Order the consumers** with `dependsOn` / `after` when one needs the
///   result of another: they all mutate the same instance, in plan order.
class XcodeprojResource extends Resource<XcodeProject> {
  /// The key of the iOS project, `xcodeproj:ios`.
  static const iosKey = ResourceKey<XcodeProject>('xcodeproj:ios');

  /// The key of the macOS project, `xcodeproj:macos`.
  static const macosKey = ResourceKey<XcodeProject>('xcodeproj:macos');

  /// The iOS project bundle, relative to the project.
  static const iosProject = 'ios/Runner.xcodeproj';

  /// The macOS project bundle, relative to the project.
  static const macosProject = 'macos/Runner.xcodeproj';

  /// The iOS `project.pbxproj`, as the processors track it.
  static const iosArtifact = Artifact.patched('$iosProject/$_pbxproj');

  /// The macOS `project.pbxproj`, as the processors track it.
  static const macosArtifact = Artifact.patched('$macosProject/$_pbxproj');

  static const _pbxproj = 'project.pbxproj';

  @override
  final ResourceKey<XcodeProject> key;

  /// The project bundle, relative to the project.
  final String projectPath;

  final XcodeprojOpener _open;
  final XcodeprojSaver _save;

  /// How each opened project looked when it was, to tell whether it changed.
  /// It is keyed by the project, so a resource never mixes up two runs.
  final Expando<Object?> _opened = Expando('opened Xcode project');

  /// The resource of the iOS project.
  ///
  /// [open] and [save] replace [XcodeProject.open] and [XcodeProject.save],
  /// which lets a test count them.
  XcodeprojResource.ios({XcodeprojOpener? open, XcodeprojSaver? save})
    : this._(iosKey, iosProject, open, save);

  /// The resource of the macOS project. See [XcodeprojResource.ios].
  XcodeprojResource.macos({XcodeprojOpener? open, XcodeprojSaver? save})
    : this._(macosKey, macosProject, open, save);

  XcodeprojResource._(
    this.key,
    this.projectPath,
    XcodeprojOpener? open,
    XcodeprojSaver? save,
  ) : _open = open ?? XcodeProject.open,
      _save = save ?? ((project) => project.save());

  @override
  Future<XcodeProject> setup(FlavorizrContext ctx) async {
    final pbxproj = p.posix.join(projectPath, _pbxproj);

    if (!File(ctx.resolve(pbxproj)).existsSync()) {
      throw FileNotFoundException(pbxproj);
    }

    final project = await _open(ctx.resolve(projectPath));
    _opened[project] = _snapshot(project);

    return project;
  }

  @override
  Future<void> teardown(
    FlavorizrContext ctx,
    XcodeProject value, {
    required bool success,
  }) async {
    if (!success || !_changed(value)) return;

    await _save(value);
  }

  bool _changed(XcodeProject project) => !const DeepCollectionEquality().equals(
    _opened[project],
    _snapshot(project),
  );

  /// A deep copy of the model of [project]: what is compared is the content,
  /// not the text it is written as, and not the live objects, which a
  /// processor may well edit in place.
  static Object? _snapshot(Object? value) => switch (value) {
    XcodeProject() => _snapshot(value.toHash()),
    Map() => {
      for (final entry in value.entries) entry.key: _snapshot(entry.value),
    },
    List() => [for (final item in value) _snapshot(item)],
    _ => value,
  };
}
