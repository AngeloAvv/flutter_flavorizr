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
import 'package:flutter_flavorizr/src/exception/configuration_not_found_exception.dart';
import 'package:flutter_flavorizr/src/exception/missing_required_fields_exception.dart';
import 'package:flutter_flavorizr/src/exception/null_fields_exception.dart';
import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:flutter_flavorizr/src/parser/models/pubspec.dart';
import 'package:json_annotation/json_annotation.dart';

class Parser {
  static const _validExtensions = ['yaml', 'yml'];

  final String pubspecPath;
  final String flavorizrPath;

  const Parser({
    required this.pubspecPath,
    required this.flavorizrPath,
  });

  Flavorizr parse() {
    assert(flavorizrPath.isNotEmpty || pubspecPath.isNotEmpty);

    final validFileNames = [
      flavorizrPath,
      pubspecPath,
    ].expand(
      (fileName) =>
          _validExtensions.map((extension) => [fileName, extension].join('.')),
    ).where((fileName) => fileName.isNotEmpty);

    final configFileName = validFileNames.firstWhereOrNull(
      (fileName) => File(fileName).existsSync(),
    );

    if (configFileName == null) {
      throw const ConfigurationNotFoundException();
    }

    final file = File(configFileName);

    try {
      if (configFileName.contains(flavorizrPath)) {
        final yaml = file.readAsStringSync();
        return Flavorizr.parse(yaml);
      } else {
        final yaml = file.readAsStringSync();
        return Pubspec.parse(yaml).flavorizr;
      }
    } on DisallowedNullValueException catch (e) {
      throw NullFieldsException(e.keysWithNullValues);
    } on MissingRequiredKeysException catch (e) {
      throw MissingRequiredFieldsException(e.missingKeys);
    }
  }
}
