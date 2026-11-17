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

/// Thrown when the configuration removes every flavor that `flavorizr.lock`
/// says was applied.
///
/// flavorizr can remove the files of a flavor, but not undo what it did to the
/// ones that were already there: the values it owns overwrite the original ones
/// (`android:label`, `CFBundleName`) and the originals are not stored.
/// Un-flavorizing a project is out of scope for 3.0.
///
/// Nothing was written to the project.
class LastFlavorRemovalException implements Exception {
  /// The flavors the lock records, which the configuration no longer has.
  final List<String> flavors;

  LastFlavorRemovalException(Iterable<String> flavors)
    : flavors = List.unmodifiable(flavors.toList()..sort());

  @override
  String toString() =>
      'Aborted: flavorizr.yaml removes every flavor (${flavors.map(printablePath).join(', ')}), '
      'so nothing was written.\n'
      'flavorizr cannot undo what it did: the values it owns, such as '
      'android:label of the manifest, replaced the original ones, and the '
      'originals are not stored. Un-flavorizing a project is out of scope for '
      'flavorizr 3.0.\n'
      'To keep using flavorizr, leave at least one flavor in flavorizr.yaml. '
      'To stop flavorizing the project, do it by hand:\n'
      '  1. restore the files flavorizr changed (the manifest, build.gradle, '
      'the plists...) from version control, or put the original values back;\n'
      '  2. delete the files it generated and flavorizr.lock, which lists them;\n'
      '  3. remove flavorizr.yaml.';
}
