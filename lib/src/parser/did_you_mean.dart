/*
 * Copyright (c) 2024 Angelo Cassano
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

/// The key of [known] that [unknown] is most likely a typo or another spelling
/// of, or `null` when none is close enough.
///
/// A key that only differs by case, underscores or dashes (`bundle_id` for
/// `bundleId`) is always the one meant. Otherwise the closest by edit distance
/// is, when it is at most a third of the length of the key.
String? didYouMean(String unknown, Iterable<String> known) {
  String normalize(String key) =>
      key.toLowerCase().replaceAll(RegExp(r'[_\-\s]'), '');

  final wanted = normalize(unknown);

  for (final key in known) {
    if (normalize(key) == wanted) return key;
  }

  String? best;
  // At most a third of the key, rounded up, between one and three edits: the
  // length is the one of the key without its separators and case, which is what
  // is compared.
  var bestDistance = (wanted.length / 3).ceil().clamp(1, 3) + 1;

  for (final key in known) {
    final distance = _distance(wanted, normalize(key));

    if (distance < bestDistance) {
      best = key;
      bestDistance = distance;
    }
  }

  return best;
}

/// The Levenshtein distance between [a] and [b].
int _distance(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;

  var previous = List<int>.generate(b.length + 1, (i) => i);

  for (var i = 1; i <= a.length; i++) {
    final current = List<int>.filled(b.length + 1, 0)..[0] = i;

    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;

      current[j] = [
        current[j - 1] + 1,
        previous[j] + 1,
        previous[j - 1] + cost,
      ].reduce((x, y) => x < y ? x : y);
    }

    previous = current;
  }

  return previous[b.length];
}
