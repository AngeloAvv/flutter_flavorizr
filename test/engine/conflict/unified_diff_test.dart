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

import 'package:flutter_flavorizr/src/engine/conflict/unified_diff.dart';
import 'package:flutter_test/flutter_test.dart';

String lines(Iterable<String> items) => items.map((i) => '$i\n').join();

String diff(String oldText, String newText, {bool color = false}) =>
    unifiedDiff(
      oldText: oldText,
      newText: newText,
      oldLabel: 'a/f.txt',
      newLabel: 'b/f.txt',
      color: color,
    );

void main() {
  test('identical texts have no diff', () {
    expect(diff('a\nb\n', 'a\nb\n'), isEmpty);
    expect(diff('', ''), isEmpty);
  });

  test('a changed line is shown with its context', () {
    final old = lines(['1', '2', '3', '4', '5', '6', '7']);
    final updated = lines(['1', '2', '3', 'four', '5', '6', '7']);

    expect(
      diff(old, updated),
      '--- a/f.txt\n'
      '+++ b/f.txt\n'
      '@@ -1,7 +1,7 @@\n'
      ' 1\n'
      ' 2\n'
      ' 3\n'
      '-4\n'
      '+four\n'
      ' 5\n'
      ' 6\n'
      ' 7\n',
    );
  });

  test('only three lines of context are kept around a change', () {
    final old = lines(['1', '2', '3', '4', '5', '6', '7', '8', '9']);
    final updated = lines(['1', '2', '3', '4', 'five', '6', '7', '8', '9']);

    expect(
      diff(old, updated),
      '--- a/f.txt\n'
      '+++ b/f.txt\n'
      '@@ -2,7 +2,7 @@\n'
      ' 2\n'
      ' 3\n'
      ' 4\n'
      '-5\n'
      '+five\n'
      ' 6\n'
      ' 7\n'
      ' 8\n',
    );
  });

  test('distant changes make separate hunks', () {
    final base = List.generate(20, (i) => '${i + 1}');
    final changed = [...base]
      ..[1] = 'two'
      ..[17] = 'eighteen';
    final result = diff(lines(base), lines(changed));

    expect(result, contains('@@ -1,5 +1,5 @@'));
    expect(result, contains('@@ -15,6 +15,6 @@'));
    expect(RegExp('^@@', multiLine: true).allMatches(result), hasLength(2));
  });

  test('close changes share a hunk', () {
    final base = List.generate(12, (i) => '${i + 1}');
    final changed = [...base]
      ..[2] = 'three'
      ..[8] = 'nine';

    expect(
      RegExp(
        '^@@',
        multiLine: true,
      ).allMatches(diff(lines(base), lines(changed))),
      hasLength(1),
    );
  });

  test('a new file is all additions', () {
    expect(
      diff('', lines(['a', 'b'])),
      '--- a/f.txt\n'
      '+++ b/f.txt\n'
      '@@ -0,0 +1,2 @@\n'
      '+a\n'
      '+b\n',
    );
  });

  test('a deleted file is all removals', () {
    expect(
      diff(lines(['a', 'b']), ''),
      '--- a/f.txt\n'
      '+++ b/f.txt\n'
      '@@ -1,2 +0,0 @@\n'
      '-a\n'
      '-b\n',
    );
  });

  test('a single line range omits its length', () {
    expect(
      diff('a\n', 'b\n'),
      '--- a/f.txt\n'
      '+++ b/f.txt\n'
      '@@ -1 +1 @@\n'
      '-a\n'
      '+b\n',
    );
  });

  test('a difference in the final newline alone is shown', () {
    expect(
      diff('a\nb\n', 'a\nb'),
      '--- a/f.txt\n'
      '+++ b/f.txt\n'
      '@@ -1,2 +1,2 @@\n'
      ' a\n'
      '-b\n'
      '+b\n'
      '\\ No newline at end of file\n',
    );
  });

  test('inserted lines are found between unchanged ones', () {
    expect(
      diff(lines(['a', 'c']), lines(['a', 'b', 'c'])),
      '--- a/f.txt\n'
      '+++ b/f.txt\n'
      '@@ -1,2 +1,3 @@\n'
      ' a\n'
      '+b\n'
      ' c\n',
    );
  });

  test('without color there is no escape sequence', () {
    expect(diff('a\n', 'b\n'), isNot(contains('\x1B')));
  });

  test('display changes what is shown, not what is compared', () {
    final result = unifiedDiff(
      oldText: 'a\x1B\n',
      newText: 'a?\n',
      oldLabel: 'old',
      newLabel: 'new',
      display: (text) => text.replaceAll('\x1B', '?'),
    );

    expect(result, contains('-a?\n+a?\n'));
  });

  test('with color additions are green, removals red, headers marked', () {
    final result = diff('a\n', 'b\n', color: true);

    expect(result, contains('\x1B[31m-a\x1B[0m'));
    expect(result, contains('\x1B[32m+b\x1B[0m'));
    expect(result, contains('\x1B[36m@@ -1 +1 @@\x1B[0m'));
    expect(result, contains('\x1B[1m--- a/f.txt\x1B[0m'));
    expect(result, contains('\x1B[1m+++ b/f.txt\x1B[0m'));
  });

  test('huge unrelated texts still produce a diff, without blowing up', () {
    final old = lines(List.generate(5000, (i) => 'old $i'));
    final updated = lines(List.generate(5000, (i) => 'new $i'));
    final result = diff(old, updated);

    expect(
      result,
      startsWith('--- a/f.txt\n+++ b/f.txt\n@@ -1,5000 +1,5000 @@'),
    );
    expect('\n-old'.allMatches(result), hasLength(5000));
    expect('\n+new'.allMatches(result), hasLength(5000));
  });
}
