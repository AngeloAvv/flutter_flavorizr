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

import 'package:flutter_flavorizr/src/engine/processors/windows/windows_source_comments.dart';
import 'package:flutter_test/flutter_test.dart';

/// The text of the comments that [WindowsSourceComments.of] finds in [source].
List<String> _comments(String source, {bool characterLiterals = true}) => [
  for (final (:start, :end) in WindowsSourceComments.of(
    source,
    characterLiterals: characterLiterals,
  ))
    source.substring(start, end),
];

void main() {
  group('WindowsSourceComments', () {
    final cases = <({String name, String source, List<String> comments})>[
      (name: 'no comment', source: 'int a = 1;\n', comments: []),
      (
        name: 'a line comment, which ends before the line break',
        source: 'a(); // note\nb();\n',
        comments: ['// note'],
      ),
      (
        name: 'a block comment over several lines',
        source: 'a(); /* x\n y */ b();',
        comments: ['/* x\n y */'],
      ),
      (
        name: 'a block comment that is not closed',
        source: 'a /* x',
        comments: ['/* x'],
      ),
      (
        name: '// and /* in a string',
        source: 'a("http://x /* y"); // c',
        comments: ['// c'],
      ),
      (
        name: 'an escaped quote in a string',
        source: r'a("x\"//y"); // c',
        comments: ['// c'],
      ),
      (
        name: 'a quote in a character',
        source: "a('\"'); // c",
        comments: ['// c'],
      ),
      (
        name: 'a digit separator, which is no character',
        source: "a(1'000); // c ' d",
        comments: ["// c ' d"],
      ),
      (
        name: 'a raw string with its delimiter',
        source: 'a(R"x(// ")" )x"); // c',
        comments: ['// c'],
      ),
      (
        name: 'a string that is not closed ends with its line',
        source: 'a("x\n// c\n',
        comments: ['// c'],
      ),
      (
        name: 'a quote in a comment',
        source: '// "x\n"//y" // c',
        comments: ['// "x', '// c'],
      ),
      (
        name: 'a name that ends with R is not a raw string',
        source: 'fooR"//"; // c',
        comments: ['// c'],
      ),
    ];

    for (final testCase in cases) {
      test(testCase.name, () {
        expect(_comments(testCase.source), testCase.comments);
      });
    }

    test('a script has no characters: an apostrophe is only text', () {
      expect(
        _comments("// it's\nVALUE \"a\", \"b\" // c", characterLiterals: false),
        ["// it's", '// c'],
      );
      expect(_comments("// it's\n' // x"), ["// it's"]);
    });

    test('contains says whether an offset is in a comment', () {
      final comments = WindowsSourceComments.of('a // b\nc');

      expect(WindowsSourceComments.contains(comments, 1), isFalse);
      expect(WindowsSourceComments.contains(comments, 2), isTrue);
      expect(WindowsSourceComments.contains(comments, 6), isFalse);
    });
  });
}
