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

import 'dart:math';

/// The candidate that [name] most likely meant, or `null` when none is close
/// enough to be worth suggesting.
///
/// Closeness is the edit distance, ignoring case. Ties go to the candidate
/// that sorts first, so the suggestion never depends on the order of
/// [candidates].
String? closestMatch(String name, Iterable<String> candidates) {
  final wanted = name.toLowerCase();
  final maxDistance = max(2, wanted.length ~/ 3);

  String? best;
  var bestDistance = maxDistance + 1;
  for (final candidate in candidates.toList()..sort()) {
    final distance = _editDistance(wanted, candidate.toLowerCase());
    // A candidate no longer than its distance would be a rewrite, not a typo.
    if (distance < bestDistance && distance < candidate.length) {
      best = candidate;
      bestDistance = distance;
    }
  }

  return best;
}

/// The Damerau-Levenshtein distance (optimal string alignment) between [a] and
/// [b]: insertions, deletions, substitutions and swaps of two adjacent
/// characters each cost one.
int _editDistance(String a, String b) {
  final table = [
    for (var i = 0; i <= a.length; i++)
      [for (var j = 0; j <= b.length; j++) i == 0 ? j : (j == 0 ? i : 0)],
  ];

  for (var i = 1; i <= a.length; i++) {
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      var distance = min(
        min(table[i - 1][j] + 1, table[i][j - 1] + 1),
        table[i - 1][j - 1] + cost,
      );
      if (i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1]) {
        distance = min(distance, table[i - 2][j - 2] + 1);
      }
      table[i][j] = distance;
    }
  }

  return table[a.length][b.length];
}
