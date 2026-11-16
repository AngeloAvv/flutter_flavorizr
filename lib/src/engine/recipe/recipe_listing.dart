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

/// A recipe and what it expands to, as `flavorizr list` shows it.
final class RecipeListing {
  /// The name of the recipe.
  final String name;

  /// Whether the recipe ships with flavorizr.
  final bool builtIn;

  /// Whether the recipe runs when no target is given.
  final bool isDefault;

  /// What the recipe lists: processor ids and other recipes.
  final List<String> members;

  /// The processors the recipe runs, with nested recipes expanded and
  /// duplicates removed. Platforms are not filtered: it is what the recipe
  /// stands for, not what a given project runs.
  final List<String> expansion;

  /// Creates a listing.
  const RecipeListing({
    required this.name,
    required this.builtIn,
    required this.isDefault,
    required this.members,
    required this.expansion,
  });

  /// Whether [members] are already the processors the recipe runs, so that
  /// there is nothing to expand.
  bool get isFlat =>
      members.length == expansion.length &&
      [
        for (var i = 0; i < members.length; i++) members[i] == expansion[i],
      ].every((same) => same);

  /// The listing as text: the name with its markers, then the members, then
  /// the expansion when it differs from the members.
  @override
  String toString() {
    final markers = [if (builtIn) 'built-in', if (isDefault) 'default'];

    return [
      markers.isEmpty ? name : '$name (${markers.join(', ')})',
      '  contains: ${members.isEmpty ? 'nothing' : members.join(', ')}',
      if (!isFlat) '  expands to: ${expansion.join(', ')}',
    ].join('\n');
  }
}
