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
import 'package:flutter_flavorizr/src/engine/darwin/owned_objects.dart';

/// The type Xcode gives a `.xcconfig` file, in `lastKnownFileType`.
const _xcconfigFileType = 'text.xcconfig';

/// Makes sure the project of [owned] references the file at [path], and returns
/// the reference. [path] is relative to the group the reference is in, as the
/// project spells it (`Flutter/appleDebug.xcconfig`).
///
/// The reference is made through [OwnedObjects.ensure]: its UUID comes from the
/// **path** (the seed `flavorizr/ios/@project/@all/xcconfigFileReference/Flutter/
/// appleDebug.xcconfig`, for instance), so two runs from scratch write the same project, the
/// next run finds it again, and [OwnedObjects.settle] removes it by UUID, with
/// everything that refers to it, when the flavor is dropped. The seed is not
/// the one of `DarwinBuildConfigurations`' reference to the same file, so the
/// processor that makes the build configurations finds this one by its path and
/// uses it as it is, instead of owning it too.
///
/// The reference goes in the group named [groupName], or in the main group, and
/// **only there**: a flavor xcconfig is a base configuration of the build
/// configurations, which is how Xcode reads it, never a resource. 2.x also put
/// it in the Resources phase of the first target (as `DarwinAddFileProcessor`
/// does for any file), which copied the xcconfigs into the app bundle: see
/// [removeXcconfigsFromResources], which cleans that.
///
/// A file that is referenced already, wherever, is used and not duplicated. It is
/// **foreign** (it is not owned, so it is never removed) unless the lock
/// recorded it for the processor: it is what 2.x made, or the user, and only a
/// lock tells which. It is given the type 2.x did not write
/// (`lastKnownFileType` is `text.xcconfig`, as Xcode has it) when it has none.
///
/// The project is not opened or saved here: it is the shared one of the run.
/// Throws a [StateError] when a new reference is needed and there is no group
/// named [groupName].
PBXFileReference ensureXcconfigReference(
  OwnedObjects owned,
  String path, {
  String? groupName,
}) {
  final project = owned.project;

  return owned.ensure<PBXFileReference>(
    (g, u) => PBXFileReference(g, u),
    kind: ['xcconfigFileReference', ...path.split('/')],
    existing: () =>
        project.files.where((file) => file.path == path).firstOrNull,
    create: (file) {
      file.path = path;
      file.sourceTree = '<group>';
      _group(project, groupName).children.add(file);
    },
  )..lastKnownFileType ??= _xcconfigFileType;
}

/// Takes the flavor xcconfigs out of every Resources build phase of [project].
///
/// A flavor xcconfig is a file that is named the way flavorizr names them, in
/// the folder it puts them in: `Flutter/<flavor>Debug.xcconfig` on iOS,
/// `Runner/Configs/<flavor>Debug.xcconfig` on macOS, and the same with
/// `Profile` and `Release`. The flavor is **any** name (the project may have
/// been flavorized with flavors `flavorizr.yaml` has not anymore, and no lock
/// tells which ones), so the rule is the name and not the configuration, in
/// every target, whatever the group the reference is in and whichever reference
/// of the same path the entry points at. Nothing else is touched: not the other
/// xcconfigs (`Flutter/Debug.xcconfig`, the ones of Pods, the ones of the user
/// that are named otherwise, which includes any other case), and not the
/// entries of the phases that are not Resources.
///
/// An entry that other phases list as well is taken out of the Resources ones
/// only, and stays whole in the others. The references themselves stay.
///
/// It is idempotent.
void removeXcconfigsFromResources(XcodeProject project) {
  final removed = <PBXBuildFile>{};

  for (final target in project.targets.whereType<PBXNativeTarget>()) {
    for (final phase
        in target.buildPhases.whereType<PBXResourcesBuildPhase>()) {
      for (final entry in phase.files.toList()) {
        final reference = entry.fileRef;

        if (reference is PBXFileReference && _isFlavorXcconfig(reference)) {
          phase.files.remove(entry);
          removed.add(entry);
        }
      }
    }
  }

  // An entry that no phase lists anymore is let go, so that it is not written.
  for (final entry in removed) {
    if (!entry.referrers.any((referrer) => referrer is AbstractBuildPhase)) {
      entry.fileRef = null;
    }
  }
}

bool _isFlavorXcconfig(PBXFileReference reference) =>
    _flavorPath.hasMatch(reference.path ?? '');

PBXGroup _group(XcodeProject project, String? name) {
  if (name == null) return project.mainGroup;

  return project.groups.firstWhere(
    (group) => group.name == name,
    orElse: () => throw StateError(
      'The group `$name` was not found in the Xcode project, so the xcconfig '
      'files of the flavors cannot be added to it.',
    ),
  );
}

/// The file name of a flavor xcconfig: the flavor and the mode, as a regular
/// expression. The xcconfigs of the templates of Flutter have no flavor
/// (`Flutter/Debug.xcconfig`), so the two are told apart.
const _flavorXcconfigFile = r'[^/\s";*]+(?:Debug|Profile|Release)\.xcconfig';

/// The path of the file reference to a flavor xcconfig.
final _flavorPath = RegExp(
  '^(?:Flutter|Runner/Configs)/$_flavorXcconfigFile\$',
);

/// The definition of the file reference to a flavor xcconfig, which is in
/// `Flutter/` (iOS) or `Runner/Configs/` (macOS).
final _flavorReference = RegExp(
  'path = "?(?:Flutter|Runner/Configs)/$_flavorXcconfigFile"?;',
);

/// The entries that put such a file in the Resources phase, which are annotated
/// by the name of the file, with or without its folder.
final _flavorResource = RegExp(
  '/\\* (?:[^/\\s*]+/)*$_flavorXcconfigFile in Resources \\*/',
);

/// The part of a `project.pbxproj` the references of [addXcconfigReference]
/// make up, which is what the lock hashes for the processors that write them:
///
/// * the definitions of the file references to the flavor xcconfigs, and
/// * the entries that put them in the Resources phase, which are none when the
///   project is as it should be. An xcconfig that is a resource again is
///   something the processor changes, so it has to show.
///
/// The rest of the project belongs to Xcode, to CocoaPods, to Flutter, to the
/// user and to the other processors, so an edit of it is not drift in what these
/// processors own. In particular a 2.x processor that runs after the engine
/// changes the project, and the next run must not see it as an edit by hand.
///
/// A reference to an xcconfig of the user that is named like the ones of the
/// flavors, in these folders, is taken for one of them.
String xcconfigReferencesOwnedContent(String source) => source
    .split(RegExp(r'\r?\n'))
    .where(
      (line) =>
          (line.contains('isa = PBXFileReference;') &&
              _flavorReference.hasMatch(line)) ||
          _flavorResource.hasMatch(line),
    )
    .join('\n');
