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

/// The keywords that only describe, and the ones [validateJson] checks. Any
/// other keyword of a schema is an error: a validator that silently ignores
/// what it does not know would pass whatever it is given.
const _annotations = {r'$schema', r'$id', r'$defs', 'title', 'description'};
const _checked = {
  r'$ref',
  'allOf',
  'oneOf',
  'if',
  'then',
  'const',
  'enum',
  'type',
  'required',
  'properties',
  'items',
  'minimum',
  'additionalProperties',
};

/// What is wrong with [instance] according to [schema], one line each: empty
/// when it is valid.
///
/// It is the part of JSON Schema (2020-12) that `doc/schemas` uses, which is
/// enough to hold the documents of `--json` to their schema without a
/// dependency.
List<String> validateJson(
  Object? instance,
  Map<String, Object?> schema, {
  Map<String, Object?>? root,
  String path = r'$',
}) {
  root ??= schema;

  final unknown = schema.keys.where(
    (key) => !_checked.contains(key) && !_annotations.contains(key),
  );

  if (unknown.isNotEmpty) {
    throw UnsupportedError('Keyword not supported by the validator: $unknown');
  }

  final errors = <String>[];

  List<String> sub(Object? value, Map<String, Object?> schema, String path) =>
      validateJson(value, schema, root: root, path: path);

  if (schema[r'$ref'] case final String ref) {
    errors.addAll(sub(instance, _resolve(root, ref), path));
  }

  for (final part in (schema['allOf'] as List?) ?? const []) {
    errors.addAll(sub(instance, part as Map<String, Object?>, path));
  }

  if (schema['oneOf'] case final List options) {
    final matching = options
        .where((o) => sub(instance, o as Map<String, Object?>, path).isEmpty)
        .length;

    if (matching != 1) errors.add('$path matches $matching of oneOf, not 1');
  }

  if (schema['if'] case final Map<String, Object?> condition) {
    if (sub(instance, condition, path).isEmpty) {
      if (schema['then'] case final Map<String, Object?> then) {
        errors.addAll(sub(instance, then, path));
      }
    }
  }

  if (schema.containsKey('const') && !_equal(instance, schema['const'])) {
    errors.add('$path is not ${schema['const']}');
  }

  if (schema['enum'] case final List values) {
    if (!values.any((value) => _equal(instance, value))) {
      errors.add('$path is $instance, not one of $values');
    }
  }

  if (schema['type'] case final Object type) {
    final types = type is List ? type : [type];

    if (!types.any((t) => _isType(instance, t as String))) {
      errors.add('$path is ${_typeOf(instance)}, not $types');
    }
  }

  if (schema['minimum'] case final num minimum) {
    if (instance is num && instance < minimum) {
      errors.add('$path is $instance, below $minimum');
    }
  }

  if (instance is Map<String, Object?>) {
    for (final name in (schema['required'] as List?) ?? const []) {
      if (!instance.containsKey(name)) errors.add('$path has no "$name"');
    }

    final properties = (schema['properties'] as Map<String, Object?>?) ?? {};

    for (final MapEntry(:key, :value) in properties.entries) {
      if (instance.containsKey(key)) {
        errors.addAll(
          sub(instance[key], value as Map<String, Object?>, '$path.$key'),
        );
      }
    }

    if (schema['additionalProperties'] == false) {
      for (final key in instance.keys.where(
        (k) => !properties.containsKey(k),
      )) {
        errors.add('$path has the unexpected "$key"');
      }
    }
  }

  if (instance is List && schema['items'] is Map<String, Object?>) {
    for (var i = 0; i < instance.length; i++) {
      errors.addAll(
        sub(instance[i], schema['items'] as Map<String, Object?>, '$path[$i]'),
      );
    }
  }

  return errors;
}

Map<String, Object?> _resolve(Map<String, Object?> root, String ref) {
  if (!ref.startsWith('#/')) throw UnsupportedError('Reference: $ref');

  Object? node = root;

  for (final part in ref.substring(2).split('/')) {
    node = (node as Map<String, Object?>)[part];
  }

  return node as Map<String, Object?>;
}

bool _equal(Object? a, Object? b) => a == b;

String _typeOf(Object? value) => switch (value) {
  null => 'null',
  bool() => 'boolean',
  int() => 'integer',
  num() => 'number',
  String() => 'string',
  List() => 'array',
  Map() => 'object',
  _ => '${value.runtimeType}',
};

bool _isType(Object? value, String type) => switch (type) {
  'number' => value is num,
  _ => _typeOf(value) == type,
};
