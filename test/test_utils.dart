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

import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:flutter_flavorizr/src/parser/parser.dart';
import 'package:test/test.dart';
import 'package:mason_logger/mason_logger.dart';

class TestUtils {
  static String stripEndOfLines(String input) => ['\n', '\r'].fold(
    input,
    (previousValue, element) => previousValue.replaceAll(element, ''),
  );

  static Logger quietLogger() => Logger(level: Level.quiet);

  static FlavorizrConfig parseFlavorizr(
    String pubspecPath, {
    String flavorizrPath = 'test_resources/non_existent',
  }) {
    final parser = Parser(
      pubspecPath: pubspecPath,
      flavorizrPath: flavorizrPath,
    );

    try {
      return parser.parse();
    } catch (e) {
      fail(e.toString());
    }
  }

  static void expectMatchesFile(String actual, String expectedFilePath) {
    final expected = File(expectedFilePath).readAsStringSync();

    expect(stripEndOfLines(actual), stripEndOfLines(expected));
  }

  static T withTempDir<T>(T Function(Directory dir) body) {
    final dir = Directory.systemTemp.createTempSync('flavorizr_test_');

    void cleanUp() {
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }
    }

    final result = body(dir);

    if (result is Future) {
      return result.whenComplete(cleanUp) as T;
    }

    cleanUp();
    return result;
  }
}
