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

/// Thrown when the Podfile has a layout flavorizr does not edit, because it
/// cannot do it without guessing what Ruby code means.
///
/// The Podfile belongs to the user, and flavorizr only works on the mapping of
/// build configurations `project 'Runner', { ... }`, which has to be written
/// the way `flutter create` writes it: one entry on each line. When it is not,
/// or when something makes a marker or the mapping ambiguous (a heredoc, a
/// block comment, a marker without its pair), nothing is written.
class UnsafePodfileException implements Exception {
  /// The Podfile, relative to the project.
  final String path;

  /// Why flavorizr cannot go on, ending in a period.
  final String reason;

  /// What the user can do about it.
  final String fix;

  /// Creates the exception for the Podfile at [path].
  UnsafePodfileException(this.path, {required this.reason, required this.fix});

  @override
  String toString() =>
      'Cannot flavor $path: $reason\n$fix Then run flavorizr again.';
}
