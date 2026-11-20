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

import 'package:flutter_flavorizr/src/engine/artifact.dart';
import 'package:flutter_flavorizr/src/engine/flavorizr_context.dart';
import 'package:flutter_flavorizr/src/exception/file_not_found_exception.dart';
import 'package:flutter_flavorizr/src/exception/malformed_resource_exception.dart';
import 'package:path/path.dart' as p;

/// Copies the file at [source], a path of the project the user wrote in
/// [option] of the configuration, to [destination], below the workspace of the
/// run, and tracks the copy as [Artifact.local].
///
/// The source is an input of the user, read from the real project and kept
/// inside it, links included. The copy is local: the IDEs and the builds work
/// with it, so it is written again silently on every run, never hashed in the
/// lock, and never a conflict or drift.
///
/// Returns the bytes that were copied. Throws a [FileNotFoundException] when
/// the source does not exist, a [MalformedResourceException] when it is not a
/// file, and an [ArgumentError] when it leaves the project.
Future<List<int>> copyProjectConfig(
  FlavorizrContext ctx, {
  required String source,
  required String destination,
  required String option,
}) async {
  final resolved = ctx.resolveProject(source);

  switch (FileSystemEntity.typeSync(resolved)) {
    case FileSystemEntityType.notFound:
      throw FileNotFoundException(source);
    case FileSystemEntityType.file:
      break;
    default:
      throw MalformedResourceException(source);
  }

  // `resolve` is lexical: a link inside the project may still lead out of it.
  final real = await File(resolved).resolveSymbolicLinks();
  final realProject = await ctx.projectRoot.resolveSymbolicLinks();

  if (!p.isWithin(realProject, real)) {
    throw ArgumentError.value(
      source,
      option,
      'must stay within `${ctx.projectRoot.path}`, links included',
    );
  }

  final target = File(ctx.resolve(destination));
  final bytes = await File(real).readAsBytes();

  await target.parent.create(recursive: true);
  await target.writeAsBytes(bytes);
  ctx.track(Artifact.local(destination));

  return bytes;
}

/// Refuses a [flavor] that cannot be the name of a directory.
void checkFlavorName(String flavor) {
  if (flavor.isEmpty ||
      flavor == '.' ||
      flavor == '..' ||
      flavor.contains(RegExp(r'[/\\\x00]'))) {
    throw ArgumentError.value(
      flavor,
      'flavor',
      'cannot be used as the name of a directory',
    );
  }
}
