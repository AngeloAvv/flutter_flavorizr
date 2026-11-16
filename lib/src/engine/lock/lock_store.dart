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

import 'dart:convert';
import 'dart:io';

import 'package:flutter_flavorizr/src/engine/lock/flavorizr_lock.dart';
import 'package:flutter_flavorizr/src/engine/lock/lock_codec.dart';
import 'package:path/path.dart' as p;

/// Reads and writes `flavorizr.lock` in the root of a project.
///
/// The store is only the file access: what is written, and when, is decided by
/// the engine, which must write the lock after a fully successful apply and
/// never before.
class LockStore {
  /// The name of the lock file, in the root of the project.
  static const fileName = 'flavorizr.lock';

  /// The root of the project.
  final Directory projectRoot;

  /// The version of the flavorizr that is running, used to refuse a lock
  /// written by a newer one.
  final String runningVersion;

  /// Creates the store of the lock of [projectRoot].
  const LockStore(this.projectRoot, {required this.runningVersion});

  File get _file => File(p.join(projectRoot.path, fileName));

  /// Reads the lock, or returns `null` when the project has none, which is the
  /// case of the first run.
  ///
  /// Throws an `UnsupportedLockVersionException` when the lock was written by a
  /// newer flavorizr and a `MalformedLockFileException` when it is not a lock.
  Future<FlavorizrLock?> read() async {
    final file = _file;

    if (!await file.exists()) return null;

    return LockCodec.decode(
      await file.readAsString(),
      runningVersion: runningVersion,
    );
  }

  /// Writes [lock], replacing the previous one.
  ///
  /// The content is written to a sibling file first and then moved over the
  /// lock, so an interrupted write never leaves a truncated lock behind.
  Future<void> write(FlavorizrLock lock) async {
    final file = _file;
    final temporary = File('${file.path}.tmp');

    await temporary.writeAsBytes(utf8.encode(LockCodec.encode(lock)));
    await temporary.rename(file.path);
  }
}
