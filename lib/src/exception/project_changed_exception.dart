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

/// Thrown when copy-back finds that files of the real project changed after
/// they were copied into the shadow workspace.
///
/// Nothing was written to the project.
class ProjectChangedException implements Exception {
  /// The paths that changed, relative to the project.
  final List<String> paths;

  ProjectChangedException(Iterable<String> paths)
    : paths = List.unmodifiable(paths);

  @override
  String toString() =>
      'Aborted: ${paths.length == 1 ? 'a file' : '${paths.length} files'} '
      'of the project changed while flutter_flavorizr was running, so nothing '
      'was written:\n'
      '${paths.map((path) => '  - $path').join('\n')}\n'
      'Run flutter_flavorizr again.';
}
