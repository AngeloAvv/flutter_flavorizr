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

import 'package:flutter_flavorizr/src/engine/conflict/terminal_text.dart';

/// Thrown when files were edited by hand and nobody can say what to do with
/// them: no one is there to answer (not a terminal, or `--yes`), no
/// `--on-conflict` policy was given, or the answers ended before the last
/// conflict was resolved.
///
/// Nothing was written to the project.
class UnresolvedConflictsException implements Exception {
  /// The conflicting paths nobody resolved, relative to the project.
  final List<String> paths;

  UnresolvedConflictsException(Iterable<String> paths)
    : paths = List.unmodifiable(paths);

  @override
  String toString() =>
      'Aborted: these files were edited by hand and the run would change '
      'them, so nothing was written:\n'
      '${paths.map((path) => '  - ${printablePath(path)}').join('\n')}\n'
      'Run again on a terminal to choose for each file, or pass '
      '--on-conflict=keep|overwrite to decide for all of them.';
}
