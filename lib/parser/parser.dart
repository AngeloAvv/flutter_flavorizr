/*
 * Copyright (c) 2022 MyLittleSuite
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

import 'package:flutter_flavorizr/exception/file_not_found_exception.dart';
import 'package:flutter_flavorizr/exception/missing_required_fields_exception.dart';
import 'package:flutter_flavorizr/parser/models/pubspec.dart';
import 'package:json_annotation/json_annotation.dart';

class Parser {
  final String file;

  Parser({required this.file});

  Pubspec parse() {
    File pubspecFile = File(file);
    if (!pubspecFile.existsSync()) {
      throw FileNotFoundException(file);
    }

    String yaml = pubspecFile.readAsStringSync();

    try {
      return Pubspec.parse(yaml);
    } on DisallowedNullValueException catch (e) {
      throw MissingRequiredFieldsException(e.keysWithNullValues);
    } on MissingRequiredKeysException catch (e) {
      throw MissingRequiredFieldsException(e.missingKeys);
    }
  }
}
