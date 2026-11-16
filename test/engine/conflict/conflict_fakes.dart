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

import 'dart:collection';

import 'package:flutter_flavorizr/src/engine/conflict/conflict_content.dart';
import 'package:flutter_flavorizr/src/engine/conflict/conflict_terminal.dart';
import 'package:flutter_flavorizr/src/engine/ownership.dart';
import 'package:flutter_flavorizr/src/engine/shadow/workspace_diff.dart';
import 'package:flutter_test/flutter_test.dart';

/// A terminal that answers from a script and records everything it was shown.
class FakeTerminal implements ConflictTerminal {
  @override
  final bool isInteractive;

  @override
  final bool supportsColor;

  final Queue<String?> _answers;

  /// The prompts the user was asked, in order.
  final List<String> prompts = [];

  /// Everything written to the terminal.
  final StringBuffer output = StringBuffer();

  FakeTerminal({
    this.isInteractive = true,
    this.supportsColor = false,
    Iterable<String?> answers = const [],
  }) : _answers = Queue.of(answers);

  /// The answers that were never asked for.
  List<String?> get unusedAnswers => _answers.toList();

  @override
  void write(String text) => output.write(text);

  @override
  Future<String?> readAnswer(String prompt) async {
    prompts.add(prompt);

    // Running out of answers is a test bug, not an end of input.
    if (_answers.isEmpty) fail('asked "$prompt" with no answer left');

    return _answers.removeFirst();
  }
}

/// A content source that serves strings.
class FakeContent implements ConflictContent {
  final Map<String, String> current;
  final Map<String, String> desired;

  FakeContent({this.current = const {}, this.desired = const {}});

  @override
  Future<List<int>?> readCurrent(String path) async => _bytes(current[path]);

  @override
  Future<List<int>?> readDesired(String path) async => _bytes(desired[path]);

  List<int>? _bytes(String? text) => text?.codeUnits;
}

/// A change judged as a conflict.
FileChange conflict(
  String path, {
  ChangeKind kind = ChangeKind.modified,
  Ownership ownership = Ownership.managed,
}) => FileChange(
  path: path,
  kind: kind,
  ownership: ownership,
  disposition: ChangeDisposition.conflict,
  before: kind == ChangeKind.added ? null : 'before',
  after: kind == ChangeKind.deleted ? null : 'after',
);

/// A change copy-back writes without asking.
FileChange applying(String path) => FileChange(
  path: path,
  kind: ChangeKind.modified,
  ownership: Ownership.managed,
  disposition: ChangeDisposition.apply,
  before: 'before',
  after: 'after',
);
