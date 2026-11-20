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
import 'package:flutter_flavorizr/src/engine/shadow/file_digest.dart';
import 'package:flutter_flavorizr/src/engine/shadow/workspace_paths.dart';
import 'package:flutter_flavorizr/src/exception/file_not_found_exception.dart';
import 'package:flutter_flavorizr/src/exception/malformed_resource_exception.dart';
import 'package:path/path.dart' as p;

/// The key under which the lock remembers a copy: the hash of what was copied.
const copyKey = 'copy';

/// Copies the file at [source], a path of the project the user wrote in
/// [option] of the configuration, to [destination], below the workspace of the
/// run, and tracks the copy as [Artifact.local].
///
/// The source is an input of the user, read from the real project and kept
/// inside it, links included. The copy is local: the IDEs and the builds work
/// with it, so it is written again silently on every run, never hashed in the
/// lock, and never a conflict or drift.
///
/// The source is resolved once, and what is read is the resolved file, never
/// the path of the configuration again. Replacing the source, or a folder
/// above it, with a link between the check that it stays within the project and
/// the read is outside the threat model: `dart:io` cannot open a file relative
/// to a folder, nor without following links, and this is a command that runs on
/// the project of the user, who is the one that can write to it.
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
  ctx.ownKeys(destination, {copyKey: digestOf(bytes)});

  return bytes;
}

/// Whether [path] is where a processor makes the copy of a flavor: `name` in a
/// folder of any flavor, directly below `parent`.
///
/// [path] comes from a lock that is edited by merges and by hand, so it is not
/// trusted: what is deleted is only ever a file named like the copies are, in
/// the folder of a flavor, and nothing else the lock names.
bool isFlavorCopyPath(
  String path, {
  required String parent,
  required String name,
}) {
  final parts = p.posix.split(path);
  final prefix = p.posix.split(parent);

  return parts.length == prefix.length + 2 &&
      p.posix.isWithin(parent, path) &&
      parts.last == name;
}

/// Removes the copies of earlier runs that this one does not make, because
/// their flavor was dropped or lost its configuration.
///
/// [keep] are the destinations this run copied to, and [isCopy] tells where the
/// processor makes a copy (see [isFlavorCopyPath]). A copy goes only when the
/// lock recorded it for the processor (so flavorizr made it) and the file still
/// holds exactly what was copied: one the lock does not know, or that the user
/// changed since, is theirs and stays. Either way the processor stops
/// remembering it.
///
/// The deletion is the one of a local artifact, which no conflict stands in the
/// way of: the check above is what keeps what is the user's.
void removeStaleCopies(
  FlavorizrContext ctx, {
  required Iterable<String> keep,
  required bool Function(String path) isCopy,
}) {
  final kept = {for (final path in keep) canonicalPath(path)};

  for (final path in ctx.previousKeyFiles) {
    if (kept.contains(path) || !isCopy(path)) continue;

    final recorded = ctx.previousKeysOf(path)[copyKey];
    final file = File(ctx.resolve(path));

    if (recorded == null ||
        FileSystemEntity.typeSync(file.path, followLinks: false) !=
            FileSystemEntityType.file ||
        digestOf(file.readAsBytesSync()) != recorded) {
      continue;
    }

    file.deleteSync();
    ctx.track(Artifact.local(path));
  }
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
