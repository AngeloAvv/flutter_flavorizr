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
import 'package:flutter_flavorizr/src/exception/malformed_lock_file_exception.dart';
import 'package:path/path.dart' as p;

/// Reads and writes `flavorizr.lock` in the root of a project.
///
/// The store is only the file access: what is written, and when, is decided by
/// the engine, which must write the lock after a fully successful apply and
/// never before.
class LockStore {
  static int _staged = 0;

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

    final String content;

    try {
      content = utf8.decode(await file.readAsBytes());
    } on FormatException {
      throw const MalformedLockFileException('the file is not valid UTF-8');
    }

    return LockCodec.decode(
      // An editor may have saved the lock with a byte order mark.
      content.startsWith('\uFEFF') ? content.substring(1) : content,
      runningVersion: runningVersion,
    );
  }

  /// Writes [lock] to a sibling file, ready to replace the lock.
  ///
  /// It is the first half of [write]: a caller that has to do something else
  /// between the two, such as copy files that the lock records, stages the lock
  /// first, so that a file system that cannot hold it is found out before
  /// anything is changed, and commits it last.
  Future<StagedLock> stage(FlavorizrLock lock) async {
    // Its own file: staged locks that overlap must not publish or delete each
    // other's.
    final temporary = File(
      '${_file.path}.${pid}_${_staged++}_${DateTime.now().microsecondsSinceEpoch}.tmp',
    );

    try {
      await temporary.writeAsBytes(utf8.encode(LockCodec.encode(lock)));
    } on Object {
      if (await temporary.exists()) await temporary.delete();

      rethrow;
    }

    return StagedLock._(temporary, _file);
  }

  /// Writes [lock], replacing the previous one.
  ///
  /// The content is written to a sibling file first and then moved over the
  /// lock, so an interrupted write never leaves a truncated lock behind.
  Future<void> write(FlavorizrLock lock) async => (await stage(lock)).commit();
}

/// A lock written next to `flavorizr.lock`, that replaces it when committed.
class StagedLock {
  final File _staged;
  final File _target;

  StagedLock._(this._staged, this._target);

  /// Moves the staged lock over `flavorizr.lock`. If it cannot, the staged file
  /// is removed and the error is thrown.
  Future<void> commit() async {
    try {
      await _staged.rename(_target.path);
    } on Object {
      await discard();

      rethrow;
    }
  }

  /// Removes the staged lock and leaves `flavorizr.lock` as it was.
  Future<void> discard() async {
    if (await _staged.exists()) await _staged.delete();
  }
}
