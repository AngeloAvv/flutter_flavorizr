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

/// [value] with every map and list in it that cannot be changed, however deep.
///
/// The configuration is read by processors, which must not be able to change
/// it: what one of them sees is what the next one sees.
Object? freeze(Object? value) => switch (value) {
  final Map map => Map<Object?, Object?>.unmodifiable({
    for (final entry in map.entries) entry.key: freeze(entry.value),
  }),
  final List list => List<Object?>.unmodifiable(list.map(freeze)),
  _ => value,
};

/// [map] that cannot be changed. Its values are the ones of [map]: they are
/// models, which cannot be changed either.
Map<K, V> frozenMap<K, V>(Map<K, V> map) => Map<K, V>.unmodifiable(map);

/// [list] that cannot be changed.
List<T> frozenList<T>(List<T> list) => List<T>.unmodifiable(list);
