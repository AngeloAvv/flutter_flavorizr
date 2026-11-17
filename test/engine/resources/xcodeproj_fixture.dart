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
import 'package:flutter_flavorizr/src/engine/flavorizr_context.dart';
import 'package:flutter_flavorizr/src/engine/flavorizr_processor.dart';
import 'package:flutter_flavorizr/src/engine/resource_key.dart';
import 'package:path/path.dart' as p;

/// A processor that mutates the shared project the way a Darwin one does,
/// without ever saving it.
class XcodeprojTestProcessor extends FlavorizrProcessor {
  @override
  final String id;

  final ResourceKey<XcodeProject> key;
  final Artifact artifact;
  final void Function(XcodeProject project) mutate;
  final Object? error;

  /// The project instance this processor was handed.
  XcodeProject? seen;

  XcodeprojTestProcessor(
    this.id,
    this.key,
    this.artifact,
    this.mutate, {
    this.error,
    Set<String> after = const {},
  }) : _after = after;

  final Set<String> _after;

  @override
  Set<String> get after => _after;

  @override
  Set<ResourceKey<Object?>> get requires => {key};

  @override
  Future<void> apply(FlavorizrContext ctx) async {
    seen = ctx.resource(key);
    ctx.track(artifact);
    mutate(seen!);
    if (error != null) throw error!;
  }
}

/// What the 2.x `DarwinAddFileProcessor` does to the project, without saving
/// it: the engine does, once.
void addFileReference(XcodeProject project, String path) {
  final group = project.mainGroup;
  final alreadyAdded = group.children.whereType<PBXFileReference>().any(
    (f) => f.path == path,
  );

  if (alreadyAdded) return;

  final ref = project.newObject<PBXFileReference>(
    (g, u) => PBXFileReference(g, u),
  );
  ref.path = path;
  ref.sourceTree = '<group>';
  ref.lastKnownFileType = FileTypes.byExtension[p.extension(path)];
  group.children.add(ref);
  (project.targets.first as PBXNativeTarget).addResources([ref]);
}
