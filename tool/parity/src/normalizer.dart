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

import 'pbxproj_normalizer.dart';

final _timestamp = RegExp(
  r'\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:?\d{2})?',
);

/// Removes the non-deterministic parts of a generated file so that two runs of
/// the same flavorizr version produce byte-identical output.
class Normalizer {
  const Normalizer();

  /// Normalizes [content], the text of the file at [relativePath].
  String normalize(String relativePath, String content) {
    final stripped = content.replaceAll(_timestamp, '<TIMESTAMP>');

    if (relativePath.endsWith('.pbxproj')) {
      return normalizePbxproj(stripped);
    }
    if (relativePath == 'pubspec.yaml') {
      return stripped.replaceAll(_flavorizrDependency, '');
    }

    return stripped;
  }
}

/// The `flutter_flavorizr` dev dependency, with its `path:` lines if any:
/// it records where the tested flavorizr comes from, not what it produced.
final _flavorizrDependency = RegExp(
  r'^  flutter_flavorizr:.*\n(?:    .*\n)*',
  multiLine: true,
);
