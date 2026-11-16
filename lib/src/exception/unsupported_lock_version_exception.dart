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

/// Thrown when `flavorizr.lock` was written by a newer flutter_flavorizr than
/// the one that is running, so it may hold things this one does not know and
/// would silently drop.
class UnsupportedLockVersionException implements Exception {
  /// The version of flutter_flavorizr that wrote the lock, when the lock says.
  final String? lockVersion;

  /// The version of the lock format, when it is the reason of the refusal.
  final int? schemaVersion;

  /// The version of flutter_flavorizr that is running.
  final String runningVersion;

  const UnsupportedLockVersionException({
    this.lockVersion,
    this.schemaVersion,
    required this.runningVersion,
  });

  @override
  String toString() {
    final writer = lockVersion == null
        ? 'a newer flutter_flavorizr'
        : 'flutter_flavorizr $lockVersion';
    final format = schemaVersion == null
        ? ''
        : ' (lock format version $schemaVersion)';

    return 'flavorizr.lock was written by $writer$format, which is newer '
        'than the running flutter_flavorizr $runningVersion. '
        'Upgrade flutter_flavorizr to ${lockVersion ?? 'the latest version'} '
        'or later and run it again: running an older version could discard '
        'what the newer one recorded.';
  }
}
