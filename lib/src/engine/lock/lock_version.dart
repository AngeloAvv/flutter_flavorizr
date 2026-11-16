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

/// Compares two semantic versions (`1.2.3`, `1.2.3-beta.1`, `1.2.3+build`),
/// ignoring build metadata.
///
/// Returns a negative number when [a] is lower than [b], zero when they have
/// the same precedence and a positive number when [a] is higher. Throws a
/// [FormatException] when either is not a semantic version.
int compareVersions(String a, String b) {
  final left = _SemVer.parse(a);
  final right = _SemVer.parse(b);

  for (var i = 0; i < 3; i++) {
    final difference = left.core[i].compareTo(right.core[i]);
    if (difference != 0) return difference;
  }

  // A pre-release is lower than the release it precedes.
  if (left.preRelease.isEmpty || right.preRelease.isEmpty) {
    return right.preRelease.length.compareTo(left.preRelease.length);
  }

  for (var i = 0; i < left.preRelease.length; i++) {
    if (i >= right.preRelease.length) return 1;

    final difference = _compareIdentifiers(
      left.preRelease[i],
      right.preRelease[i],
    );
    if (difference != 0) return difference;
  }

  return left.preRelease.length.compareTo(right.preRelease.length);
}

// Numeric identifiers are lower than alphanumeric ones and compare as numbers.
int _compareIdentifiers(String a, String b) {
  final numberA = int.tryParse(a);
  final numberB = int.tryParse(b);

  if (numberA != null && numberB != null) return numberA.compareTo(numberB);
  if (numberA != null) return -1;
  if (numberB != null) return 1;

  return a.compareTo(b);
}

final class _SemVer {
  static final _pattern = RegExp(
    r'^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)'
    r'(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?'
    r'(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$',
  );

  final List<int> core;
  final List<String> preRelease;

  const _SemVer(this.core, this.preRelease);

  factory _SemVer.parse(String version) {
    final match = _pattern.firstMatch(version);

    if (match == null) {
      throw FormatException('Not a semantic version', version);
    }

    return _SemVer([
      for (var i = 1; i <= 3; i++) int.parse(match.group(i)!),
    ], match.group(4)?.split('.') ?? const []);
  }
}
