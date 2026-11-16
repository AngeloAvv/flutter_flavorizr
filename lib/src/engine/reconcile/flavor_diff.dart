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

/// The difference between the flavors the configuration asks for and the
/// flavors the lock says were applied.
///
/// Every list is sorted by name.
final class FlavorDiff {
  /// The flavors in the configuration the lock does not know.
  final List<String> added;

  /// The flavors in the lock the configuration no longer has.
  final List<String> removed;

  /// The flavors in both, whose resolved configuration changed.
  final List<String> changed;

  /// The flavors in both, whose resolved configuration did not change.
  final List<String> unchanged;

  /// The removed flavors that look renamed, by old name: a flavor was removed
  /// and another added with exactly the same resolved configuration.
  ///
  /// It is a hint for the plan and nothing more. A rename is always applied as
  /// the removal of [removed] plus the addition of [added].
  final Map<String, String> renamed;

  /// Creates a diff.
  FlavorDiff({
    required Iterable<String> added,
    required Iterable<String> removed,
    required Iterable<String> changed,
    required Iterable<String> unchanged,
    Map<String, String> renamed = const {},
  }) : added = List.unmodifiable(added.toList()..sort()),
       removed = List.unmodifiable(removed.toList()..sort()),
       changed = List.unmodifiable(changed.toList()..sort()),
       unchanged = List.unmodifiable(unchanged.toList()..sort()),
       renamed = Map.unmodifiable(renamed);

  /// Whether the configuration and the lock agree.
  bool get isEmpty => added.isEmpty && removed.isEmpty && changed.isEmpty;

  /// The diff as text, one line per flavor, ready to be shown in the plan.
  ///
  /// A rename is spelled out: the plan never hides that the old flavor goes
  /// away and a new one is created.
  String render() {
    if (isEmpty) return 'No flavor changes.';

    final oldNames = renamed.keys.toList()..sort();

    return [
      for (final name in removed) '- $name (removed)',
      for (final name in added) '+ $name (added)',
      for (final name in changed) '~ $name (changed)',
      for (final old in oldNames)
        '$old -> ${renamed[old]} is a rename: it is applied as the removal of '
            '`$old` plus the addition of `${renamed[old]}`.',
    ].join('\n');
  }

  @override
  String toString() => render();
}

/// Compares the [desired] flavors with the [applied] ones, both mapping the
/// name of a flavor to the hash of its resolved configuration.
///
/// [applied] is `FlavorizrLock.flavors`. A flavor is told apart by its name
/// alone, so a rename is a removal plus an addition: [FlavorDiff.renamed] only
/// annotates the pairs that can be recognised without guessing.
FlavorDiff diffFlavors({
  required Map<String, String> desired,
  required Map<String, String> applied,
}) {
  final added = desired.keys.where((name) => !applied.containsKey(name));
  final removed = applied.keys.where((name) => !desired.containsKey(name));
  final kept = desired.keys.where(applied.containsKey);

  return FlavorDiff(
    added: added,
    removed: removed,
    changed: kept.where((name) => desired[name] != applied[name]),
    unchanged: kept.where((name) => desired[name] == applied[name]),
    renamed: _renames(
      removed: {for (final name in removed) name: applied[name]!},
      added: {for (final name in added) name: desired[name]!},
    ),
  );
}

/// The pairs of a removed and an added flavor that share a hash no other
/// flavor of their side shares: anything ambiguous is left unpaired.
Map<String, String> _renames({
  required Map<String, String> removed,
  required Map<String, String> added,
}) {
  final removedByHash = _byUniqueHash(removed);
  final addedByHash = _byUniqueHash(added);

  return {
    for (final MapEntry(key: hash, value: old) in removedByHash.entries)
      if (addedByHash[hash] case final String name) old: name,
  };
}

Map<String, String> _byUniqueHash(Map<String, String> flavors) {
  final byHash = <String, List<String>>{};

  for (final MapEntry(key: name, value: hash) in flavors.entries) {
    byHash.putIfAbsent(hash, () => []).add(name);
  }

  return {
    for (final MapEntry(key: hash, value: names) in byHash.entries)
      if (names.length == 1) hash: names.single,
  };
}
