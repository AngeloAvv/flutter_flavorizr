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

/// A configuration that cannot be used, with where it goes wrong.
///
/// [message] is what is wrong and [location] where it is, as
/// `flavorizr.yaml:12:7`, when it is known.
class InvalidConfigurationException implements Exception {
  /// What is wrong.
  final String message;

  /// Where it is wrong, as `file:line:column`.
  final String? location;

  /// Creates the exception.
  InvalidConfigurationException(this.message, {this.location});

  @override
  String toString() => location == null ? message : '$location: $message';
}

/// A key of flavorizr 2.x that 3.0 does not read any more.
///
/// [message] says what replaces it, with the yaml to write.
class RemovedKeyException extends InvalidConfigurationException {
  /// The key that was removed.
  final String key;

  /// Creates the exception.
  RemovedKeyException(this.key, super.message, {super.location});
}

/// A key of the configuration that flavorizr does not know, which is silently
/// ignored by nothing: a typo is far more likely than a key that does nothing.
class UnknownFieldsException extends InvalidConfigurationException {
  /// The keys that are not known.
  final List<String> fields;

  /// The path of the map they are in, empty for the top level.
  final String path;

  /// The keys that map accepts.
  final List<String> allowedKeys;

  /// The key each of [fields] is most likely to be, when there is one.
  final Map<String, String> suggestions;

  /// Creates the exception.
  UnknownFieldsException(
    this.fields, {
    required this.path,
    required this.allowedKeys,
    this.suggestions = const {},
    super.location,
  }) : super(_describe(fields, path, allowedKeys, suggestions));

  static String _describe(
    List<String> fields,
    String path,
    List<String> allowedKeys,
    Map<String, String> suggestions,
  ) {
    final where = path.isEmpty ? 'the configuration' : '`$path`';
    final unknown = fields.map((field) => '`$field`').join(', ');
    final noun = fields.length == 1 ? 'key' : 'keys';
    final hints = [
      for (final field in fields)
        if (suggestions[field] != null)
          'did you mean `${suggestions[field]}` instead of `$field`?',
    ];

    final withoutHint = fields.any((field) => suggestions[field] == null);

    return [
      'Unknown $noun $unknown in $where',
      if (hints.isNotEmpty) ': ${hints.join(' ')}',
      if (withoutHint)
        '${hints.isEmpty ? '.' : ''} The known keys are: ${allowedKeys.join(', ')}.',
    ].join();
  }
}
