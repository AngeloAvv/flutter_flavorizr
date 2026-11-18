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

    try {
      if (configFileName.contains(flavorizrPath)) {
        return Flavorizr.parse(yaml);
      } else {
        return Pubspec.parse(yaml).flavorizr;
      }
    } on ParsedYamlException catch (e) {
      throw _translate(e, yaml, configFileName);
    }
  }

  /// What a [ParsedYamlException] says, in the words of the configuration: the
  /// path of the map it is about, where it is in the file and, for a key that is
  /// not known, the one that was most likely meant.
  Exception _translate(ParsedYamlException error, String yaml, String file) {
    final node = error.yamlNode;
    final inner = error.innerError;
    final cause = inner is CheckedFromJsonException ? inner.innerError : inner;
    final root = _tryLoad(yaml);
    final location = node == null
        ? null
        : '${p.basename(file)}:${node.span.start.line + 1}:'
              '${node.span.start.column + 1}';
    final path = node == null || root == null
        ? ''
        : configContainerPathOf(root, node) ?? '';

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

  static YamlNode? _tryLoad(String yaml) {
    try {
      return loadYamlNode(yaml);
    } on YamlException {
      return null;
    }
  }
}
