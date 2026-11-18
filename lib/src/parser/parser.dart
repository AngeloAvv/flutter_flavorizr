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

import 'dart:io';

import 'package:collection/collection.dart';
import 'package:checked_yaml/checked_yaml.dart';
import 'package:flutter_flavorizr/src/exception/configuration_not_found_exception.dart';
import 'package:flutter_flavorizr/src/exception/invalid_configuration_exception.dart';
import 'package:flutter_flavorizr/src/exception/missing_required_fields_exception.dart';
import 'package:flutter_flavorizr/src/exception/null_fields_exception.dart';
import 'package:flutter_flavorizr/src/parser/config_path.dart';
import 'package:flutter_flavorizr/src/parser/did_you_mean.dart';
import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:flutter_flavorizr/src/parser/models/pubspec.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

class Parser {
  static const _validExtensions = ['yaml', 'yml'];

  final String pubspecPath;
  final String flavorizrPath;

  const Parser({required this.pubspecPath, required this.flavorizrPath});

  Flavorizr parse() {
    assert(flavorizrPath.isNotEmpty || pubspecPath.isNotEmpty);

    final validFileNames = [flavorizrPath, pubspecPath]
        .expand(
          (fileName) => _validExtensions.map(
            (extension) => [fileName, extension].join('.'),
          ),
        )
        .where((fileName) => fileName.isNotEmpty);

    final configFileName = validFileNames.firstWhereOrNull(
      (fileName) => File(fileName).existsSync(),
    );

    if (configFileName == null) {
      throw const ConfigurationNotFoundException();
    }

    final file = File(configFileName);
    final yaml = file.readAsStringSync();
    final isFlavorizrFile = configFileName.contains(flavorizrPath);

    // The document is loaded once, and decoded as it is: an error then holds
    // the very nodes of this tree, which tells where it is.
    final YamlNode root;

    try {
      root = loadYamlNode(yaml, sourceUrl: Uri.file(configFileName));
    } on YamlException catch (e) {
      throw InvalidConfigurationException(
        ParsedYamlException.fromYamlException(e).formattedMessage ?? e.message,
      );
    }

    if (root is! YamlMap) {
      throw InvalidConfigurationException(
        'The configuration must be a map of keys',
        location: _location(configFileName, root),
      );
    }

    _checkKeys(root, root, configFileName, visited: Set<YamlNode>.identity());

    try {
      return isFlavorizrFile
          ? Flavorizr.fromJson(root)
          : Pubspec.fromJson(root).flavorizr;
    } on CheckedFromJsonException catch (e) {
      throw _translate(toParsedYamlException(e), root, configFileName);
    }
  }

  /// Fails on a key that is not text, wherever it is below the configuration:
  /// the decoders compare keys as strings, and a number or a list that is a key
  /// would only be met as an error about a type, with no word about where.
  void _checkKeys(
    YamlMap root,
    YamlNode node,
    String file, {
    required Set<YamlNode> visited,
    List<Object> path = const [],
    bool lenient = false,
  }) {
    // An alias is the very same node: it is checked once.
    if (!visited.add(node)) return;

    if (node is YamlMap) {
      for (final entry in node.nodes.entries) {
        final key = entry.key as YamlNode;

        // The sections of a pubspec that are not flavorizr's are not read.
        if (identical(node, root) &&
            !_isFlavorizrFile(file) &&
            !(key is YamlScalar && key.value == 'flavorizr')) {
          continue;
        }

        // The names of the recipes are converted to text by whoever reads them,
        // so `42` is the recipe `'42'`, as it has always been.
        final isText = key is YamlScalar && key.value is String;
        final isName = key is YamlScalar && key.value is num && lenient;

        if (!isText && !isName) {
          throw InvalidConfigurationException(
            'The key `${key is YamlScalar ? key.value : key}` of '
            '${path.isEmpty ? 'the configuration' : '`${joinConfigPath(path)}`'} '
            'must be text: quote it to make it so',
            location: _location(file, key),
          );
        }

        final name = '${key.value}';
        final recipes =
            _isFlavorizrFile(file) &&
            identical(node, root) &&
            key.value == 'recipes';

        _checkKeys(
          root,
          entry.value,
          file,
          visited: visited,
          path: [...path, name],
          lenient: recipes,
        );
      }
    } else if (node is YamlList) {
      for (final (index, item) in node.nodes.indexed) {
        _checkKeys(root, item, file, visited: visited, path: [...path, index]);
      }
    }
  }

  bool _isFlavorizrFile(String file) => file.contains(flavorizrPath);

  static String _location(String file, YamlNode node) =>
      '${p.basename(file)}:${node.span.start.line + 1}:'
      '${node.span.start.column + 1}';

  /// What a [ParsedYamlException] says, in the words of the configuration: the
  /// path of the map it is about, where it is in the file and, for a key that is
  /// not known, the one that was most likely meant.
  Exception _translate(ParsedYamlException error, YamlNode root, String file) {
    final node = error.yamlNode;
    final inner = error.innerError;
    final cause = inner is CheckedFromJsonException ? inner.innerError : inner;
    final location = node == null ? null : _location(file, node);
    final path = node == null ? '' : configContainerPathOf(root, node) ?? '';

    return switch (cause) {
      UnrecognizedKeysException(:final unrecognizedKeys, :final allowedKeys) =>
        UnknownFieldsException(
          unrecognizedKeys,
          path: path,
          allowedKeys: allowedKeys,
          location: location,
          suggestions: {
            for (final key in unrecognizedKeys)
              key: ?didYouMean(key, allowedKeys),
          },
        ),
      MissingRequiredKeysException(:final missingKeys) =>
        MissingRequiredFieldsException(
          missingKeys,
          path: path,
          location: location,
        ),
      DisallowedNullValueException(:final keysWithNullValues) =>
        NullFieldsException(keysWithNullValues, path: path, location: location),
      _ => InvalidConfigurationException(
        error.formattedMessage ?? error.message,
      ),
    };
  }
}
