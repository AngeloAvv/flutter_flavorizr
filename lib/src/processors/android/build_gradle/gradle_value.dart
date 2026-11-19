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

/// The language of a Gradle script.
enum GradleDsl { groovy, kotlin }

/// Writes [value], a value of the YAML of a configuration, as an expression of
/// the Gradle script of [dsl].
///
/// * text is a string literal, escaped: `\\`, `"`, `$` and the line breaks;
/// * numbers and booleans are written as they are, `null` as `null`;
/// * a list is a list, `["a", 1]` in Groovy and `listOf("a", 1)` in Kotlin;
/// * a map is a map, `["a": 1]` in Groovy and `mapOf("a" to 1)` in Kotlin;
/// * a map with the single key `raw` is the code that is its value, written as
///   it is: `{raw: flavorSigning.green}`, which is how an expression that is
///   not a literal is told from a string.
///
/// Throws an [ArgumentError] for any other value.
String gradleValue(Object? value, GradleDsl dsl) => switch (value) {
  null => 'null',
  bool() || num() => '$value',
  String() => gradleString(value),
  {'raw': final raw} when value.length == 1 => '$raw',
  Map() => _map(value, dsl),
  Iterable() => _list(value, dsl),
  _ => throw ArgumentError.value(
    value,
    'value',
    'It is not a value Gradle can be given: use text, a number, a boolean, a '
        'list or a map.',
  ),
};

/// Whether [value] is written as a list or a map, which Groovy is given with an
/// assignment: `key = [...]`, since `key [...]` could be read as an index.
bool gradleIsCollection(Object? value) => switch (value) {
  {'raw': _} when value.length == 1 => false,
  Map() || Iterable() => true,
  _ => false,
};

/// The string literal of [text] in both languages of Gradle.
String gradleString(String text) {
  final escaped = text
      .replaceAll(r'\', r'\\')
      .replaceAll('"', r'\"')
      .replaceAll(r'$', r'\$')
      .replaceAll('\n', r'\n')
      .replaceAll('\r', r'\r')
      .replaceAll('\t', r'\t');

  return '"$escaped"';
}

String _list(Iterable<Object?> values, GradleDsl dsl) {
  final items = values.map((value) => gradleValue(value, dsl)).join(', ');

  return switch (dsl) {
    GradleDsl.groovy => '[$items]',
    GradleDsl.kotlin => 'listOf($items)',
  };
}

String _map(Map<Object?, Object?> values, GradleDsl dsl) {
  final entries = [
    for (final MapEntry(:key, :value) in values.entries)
      switch (dsl) {
        GradleDsl.groovy => '${gradleString('$key')}: ${gradleValue(value, dsl)}',
        GradleDsl.kotlin => '${gradleString('$key')} to ${gradleValue(value, dsl)}',
      },
  ].join(', ');

  return switch (dsl) {
    GradleDsl.groovy => values.isEmpty ? '[:]' : '[$entries]',
    GradleDsl.kotlin => 'mapOf($entries)',
  };
}
