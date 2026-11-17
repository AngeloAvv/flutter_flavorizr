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

/// Thrown when a file of the Windows runner is not laid out the way flavorizr
/// can edit it, so that it would have to guess.
///
/// The files are made by `flutter create`, and flavorizr edits them only where
/// it can tell what it is editing: a call that is not where or how
/// `flutter create` writes it, or that there is more than one of, is not
/// guessed at. Nothing is written.
class UnsupportedRunnerLayoutException implements Exception {
  /// The file, relative to the project.
  final String path;

  /// Why flavorizr cannot go on, ending in a period.
  final String reason;

  /// What the user can do about it, ending in a period.
  final String fix;

  /// Creates the exception for [path].
  const UnsupportedRunnerLayoutException(
    this.path, {
    required this.reason,
    required this.fix,
  });

  @override
  String toString() =>
      'Cannot flavor $path: $reason\n$fix Then run flavorizr again.';
}
