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

/// Thrown when copy-back stopped halfway: the project holds some of the
/// changes and not the others.
class CopyBackInterruptedException implements Exception {
  /// The paths already written to the project, relative to it.
  final List<String> applied;

  /// The paths that were not written.
  final List<String> pending;

  /// What stopped copy-back.
  final Object cause;

  CopyBackInterruptedException({
    required Iterable<String> applied,
    required Iterable<String> pending,
    required this.cause,
  }) : applied = List.unmodifiable(applied),
       pending = List.unmodifiable(pending);

  @override
  String toString() =>
      'Interrupted while writing to the project: $cause\n'
      'Already applied (${applied.length}):\n'
      '${_list(applied)}\n'
      'Not applied (${pending.length}):\n'
      '${_list(pending)}\n'
      'Review them with your version control, then run flutter_flavorizr '
      'again.';

  static String _list(List<String> paths) =>
      paths.isEmpty ? '  (none)' : paths.map((path) => '  - $path').join('\n');
}
