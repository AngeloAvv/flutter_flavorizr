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
import 'package:flutter_flavorizr/src/engine/flavorizr_processor.dart';
import 'package:flutter_flavorizr/src/engine/processors/project_config_copy.dart';
import 'package:flutter_flavorizr/src/engine/shadow/file_digest.dart';
import 'package:flutter_flavorizr/src/engine/shadow/workspace_paths.dart';
import 'package:flutter_flavorizr/src/utils/constants.dart';
import 'package:path/path.dart' as p;

/// The name of the file the AppGallery Connect plugin looks for in the folder
/// of the flavor that is built.
const agconnectServicesFile = 'agconnect-services.json';

/// The key under which the lock remembers the copy of a flavor: the hash of what
/// was copied.
const _copyKey = 'copy';

/// `huawei:agconnect`: the `agconnect-services.json` of each Android flavor that
/// has an AppGallery Connect configuration, in `android/app/src/<flavor>`.
///
/// The configuration of a flavor is an input of the user, read from the real
/// project. Its copy is [Artifact.local]: it is written again silently on every
/// run, never hashed as a file in the lock, and never a conflict or drift.
///
/// The lock remembers, for each copy, the hash of what was copied
/// (`FlavorizrContext.ownKeys`). It is not there to find drift: it is how a run
/// that no longer makes a copy tells it from a file of the user. A flavor that
/// loses its configuration, or that is removed, loses the copy flavorizr made
/// for it, as long as it still holds what flavorizr copied. An
/// `agconnect-services.json` the lock does not know, or that the user changed
/// since, is the user's and stays.
class AGConnectProcessor extends FlavorizrProcessor {
  /// Creates the processor.
  const AGConnectProcessor();

  @override
  String get id => 'huawei:agconnect';

  @override
  Future<void> apply(FlavorizrContext ctx) async {
    final copies = <String>{};

    for (final MapEntry(key: flavor, value: definition)
        in ctx.config.androidAGConnectFlavors.entries) {
      checkFlavorName(flavor);

      final destination = '${K.androidSrcPath}/$flavor/$agconnectServicesFile';
      final bytes = await copyProjectConfig(
        ctx,
        source: definition.android!.agconnect!.config,
        destination: destination,
        option: 'agconnect.config',
      );
      final path = canonicalPath(destination);

      copies.add(path);
      ctx.ownKeys(path, {_copyKey: digestOf(bytes)});
    }

    _removeStaleCopies(ctx, keep: copies);
  }

  /// Removes the copies of earlier runs that this one does not make.
  void _removeStaleCopies(FlavorizrContext ctx, {required Set<String> keep}) {
    for (final path in ctx.previousKeyFiles) {
      if (keep.contains(path) || !_isCopyPath(path)) continue;

      final recorded = ctx.previousKeysOf(path)[_copyKey];
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

  /// Whether [path], which comes from a lock that is edited by merges and by
  /// hand, is where this processor makes a copy.
  bool _isCopyPath(String path) {
    final parts = p.posix.split(path);
    final prefix = p.posix.split(K.androidSrcPath);

    return parts.length == prefix.length + 2 &&
        p.posix.isWithin(K.androidSrcPath, path) &&
        parts.last == agconnectServicesFile;
  }
}
