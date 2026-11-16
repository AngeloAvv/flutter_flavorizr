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

import 'dart:io';

/// The terminal conflicts are resolved on: the seam that keeps stdin and stdout
/// out of the resolution logic, so that every answer can be scripted in tests.
abstract interface class ConflictTerminal {
  /// Whether a person can answer: both input and output are a terminal.
  ///
  /// When `false`, nothing is ever asked.
  bool get isInteractive;

  /// Whether output may carry ANSI colour codes.
  bool get supportsColor;

  /// Prints [text] as is.
  void write(String text);

  /// Prints [prompt] and returns what the user typed, or `null` when the input
  /// ended and no answer will ever come.
  Future<String?> readAnswer(String prompt);
}

/// The [ConflictTerminal] of the process: stdin and stdout.
class ConsoleConflictTerminal implements ConflictTerminal {
  const ConsoleConflictTerminal();

  @override
  bool get isInteractive => stdin.hasTerminal && stdout.hasTerminal;

  @override
  bool get supportsColor =>
      stdout.hasTerminal &&
      stdout.supportsAnsiEscapes &&
      !Platform.environment.containsKey('NO_COLOR');

  @override
  void write(String text) => stdout.write(text);

  @override
  Future<String?> readAnswer(String prompt) async {
    stdout.write(prompt);

    return stdin.readLineSync();
  }
}
