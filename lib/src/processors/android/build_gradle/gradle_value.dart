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
/// * text is a string literal, escaped: `\`, `"`, `$` and the line breaks;
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
  Map() => gradleMap(value, dsl),
  Iterable() => _list(value, dsl),
  _ => throw ArgumentError.value(
    value,
    'value',
    'It is not a value Gradle can be given: use text, a number, a boolean, a '
        'list or a map.',
  ),
};

/// Whether [value] is written as a list or a map.
bool gradleIsCollection(Object? value) => switch (value) {
  {'raw': _} when value.length == 1 => false,
  Map() || Iterable() => true,
  _ => false,
};

/// The statement that gives the property [key] of a flavor the [value] of
/// `customConfig` in [dsl].
///
/// A scalar is assigned. A list *adds* its items, since the collections of a
/// flavor, such as `resourceConfigurations`, can be added to and mostly cannot
/// be assigned: `key += listOf(...)` in Kotlin, `key.addAll([...])` in Groovy.
/// Groovy is given a map with an assignment, `key = [...]`, as `key [...]`
/// could be read as an index.
String gradleProperty(String key, Object? value, GradleDsl dsl) {
  final written = gradleValue(value, dsl);

  return switch ((dsl, value)) {
    (GradleDsl.kotlin, Iterable()) => '$key += $written',
    (GradleDsl.kotlin, _) => '$key = $written',
    (GradleDsl.groovy, Iterable()) => '$key.addAll($written)',
    (GradleDsl.groovy, Map()) when gradleIsCollection(value) =>
      '$key = $written',
    (GradleDsl.groovy, _) => '$key $written',
  };
}

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
    GradleDsl.kotlin => values.isEmpty ? 'listOf<Any>()' : 'listOf($items)',
  };
}

/// [values] as a map, whatever its keys are: a map with the single key `raw` is
/// a map of one entry here, not code. It is how a container that is a map by
/// definition, such as the `manifestPlaceholders` of a flavor, is written.
String gradleMap(Map<Object?, Object?> values, GradleDsl dsl) {
  final entries = [
    for (final MapEntry(:key, :value) in values.entries)
      switch (dsl) {
        GradleDsl.groovy =>
          '${gradleString('$key')}: ${gradleValue(value, dsl)}',
        GradleDsl.kotlin =>
          '${gradleString('$key')} to ${gradleValue(value, dsl)}',
      },
  ].join(', ');

  return switch (dsl) {
    GradleDsl.groovy => values.isEmpty ? '[:]' : '[$entries]',
    GradleDsl.kotlin =>
      values.isEmpty ? 'mapOf<String, Any>()' : 'mapOf($entries)',
  };
}
