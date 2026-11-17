/*
 * Copyright (c) 2024 Angelo Cassano
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
import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:flutter_flavorizr/src/processors/commons/abstract_processor.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

class DarwinAddFileProcessor extends AbstractProcessor<void> {
  final String projectPath;
  final String filePath;
  final String? groupName;

  const DarwinAddFileProcessor(
    this.projectPath,
    this.filePath, {
    this.groupName,
    required Flavorizr config,
    required Logger logger,
  }) : super(config, logger: logger);

  @override
  Future<void> execute() async {
    final project = await XcodeProject.open(projectPath);

    if (addTo(project, filePath, groupName: groupName)) {
      await project.save();
    }
  }

  /// Adds a reference to [filePath] to the group [groupName] of [project], or
  /// to its main group, and to the resources of its first target.
  ///
  /// It is what the processor does without opening or saving the project, so
  /// that processors of the engine, which share one, do the same. Returns
  /// whether something was added: it is not when the group has the file
  /// already.
  static bool addTo(
    XcodeProject project,
    String filePath, {
    String? groupName,
  }) {
    final group = groupName == null
        ? project.mainGroup
        : project.groups.firstWhere((g) => g.name == groupName);

    final alreadyAdded = group.children.whereType<PBXFileReference>().any(
      (f) => f.path == filePath,
    );

    if (alreadyAdded) return false;

    final fileRef = project.newObject<PBXFileReference>(
      (g, u) => PBXFileReference(g, u),
    );
    fileRef.path = filePath;
    fileRef.sourceTree = '<group>';
    fileRef.lastKnownFileType =
        FileTypes.byExtension[p.extension(filePath).toLowerCase()];
    group.children.add(fileRef);

    final target = project.targets.first as PBXNativeTarget;
    target.addResources([fileRef]);

    return true;
  }

  @override
  String toString() => 'DarwinAddFileProcessor';
}
