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

/// The type Xcode gives a `.xcconfig` file, in `lastKnownFileType`.
const _xcconfigFileType = 'text.xcconfig';

/// Makes sure [project] references the file at [path] and returns the
/// reference. [path] is relative to the group the reference is in, as the
/// project spells it (`Flutter/appleDebug.xcconfig`).
///
/// The reference goes in the group named [groupName], or in the main group, and
/// **only there**: a flavor xcconfig is a base configuration of the build
/// configurations, which is how Xcode reads it, never a resource. 2.x also put
/// it in the Resources phase of the first target (as `DarwinAddFileProcessor`
/// does for any file), which copied the xcconfigs into the app bundle. So the
/// build files of the reference are taken out of every Resources phase, which
/// cleans a project 2.x flavorized, and nothing else is: the xcconfigs that this
/// call is not asked for are none of its business.
///
/// It is idempotent. A reference that is in the group already is the one used,
/// and it is given the type 2.x did not write (`lastKnownFileType` is
/// `text.xcconfig`, as Xcode has it) when it has none. The project is not
/// opened or saved here: it is the shared one of the run.
///
/// Throws a [StateError] when there is no group named [groupName].
PBXFileReference addXcconfigReference(
  XcodeProject project,
  String path, {
  String? groupName,
}) {
  final group = _group(project, groupName);
  final reference = group.children.whereType<PBXFileReference>().firstWhere(
    (file) => file.path == path,
    orElse: () {
      final created = project.newObject<PBXFileReference>(
        (g, u) => PBXFileReference(g, u),
      );

      created.path = path;
      created.sourceTree = '<group>';
      group.children.add(created);

      return created;
    },
  )..lastKnownFileType ??= _xcconfigFileType;

  _removeFromResources(project, reference);

  return reference;
}

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

void _removeFromResources(XcodeProject project, PBXFileReference reference) {
  for (final target in project.targets.whereType<PBXNativeTarget>()) {
    for (final phase
        in target.buildPhases.whereType<PBXResourcesBuildPhase>()) {
      // A build file per entry, however many a project has: bounded, so that
      // an entry that cannot be removed never loops.
      final entries = phase.files.where((file) => file.fileRef == reference);

      for (var i = entries.length; i > 0; i--) {
        phase.removeFileReference(reference);
      }
    }
  }
}

/// The file name of a flavor xcconfig: the flavor and the mode, as a regular
/// expression. The xcconfigs of the templates of Flutter have no flavor
/// (`Flutter/Debug.xcconfig`), so the two are told apart.
const _flavorXcconfigFile = r'[^/\s";*]+(?:Debug|Profile|Release)\.xcconfig';

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
