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

import 'package:flutter_flavorizr/src/engine/processors/windows/windows_source_scanner.dart';
import 'package:flutter_flavorizr/src/exception/unsupported_runner_layout_exception.dart';
import 'package:flutter_test/flutter_test.dart';

const _path = 'windows/runner/main.cpp';

/// The text of the comments that the scanner finds in [source].
List<String> _comments(String source, {bool cpp = true}) => [
  for (final (:start, :end) in WindowsSourceScanner.scan(
    source,
    path: _path,
    cpp: cpp,
  ).comments)
    source.substring(start, end),
];

void main() {
  group('WindowsSourceScanner finds the comments, knowing the literals', () {
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
        name: '/* in a line comment, and // in a block comment, are text',
        source: 'a(); // /* x\nb(); /* // */ c();',
        comments: ['// /* x', '/* // */'],
      ),
      (
        name: 'block comments do not nest',
        source: '/* /* */ a(); // c',
        comments: ['/* /* */', '// c'],
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
        name: 'a quote in a prefixed character',
        source: "a(L'\"'); a(u'\"'); a(U'\"'); a(u8'\"'); // c",
        comments: ['// c'],
      ),
      (
        name: 'a prefixed character, then a commented call',
        source:
            "wchar_t q = L'\"'; // window.Create(TITLE, origin, size);\n"
            'window.Create(L"App", origin, size);',
        comments: ['// window.Create(TITLE, origin, size);'],
      ),
      (
        name: 'a digit separator, which is no character',
        source: "a(1'000, 0x1'F); // c ' d",
        comments: ["// c ' d"],
      ),
      (
        name: 'a raw string with its delimiter',
        source: 'a(R"x(// ")" )x"); a(LR"(//)"); // c',
        comments: ['// c'],
      ),
      (
        name: 'a name that ends with R is not a raw string',
        source: 'fooR"//"; // c',
        comments: ['// c'],
      ),
      (
        name: 'a line comment that is continued, with LF and with CRLF',
        source: '// old: \\\nwindow.Create(TITLE);\nb();\n// x \\\r\ny\r\nc();',
        comments: ['// old: \\\nwindow.Create(TITLE);', '// x \\\r\ny\r'],
      ),
      (
        name: 'an include of a header',
        source:
            '#include <flutter/dart_project.h>\n#include "utils.h"\n'
            '#include "a.hpp"\n',
        comments: [],
      ),
      (
        name: 'a digraph in a string or in a comment',
        source: 'a(L"<% :> %:"); // <% %>',
        comments: ['// <% %>'],
      ),
      (
        name: 'mixed line endings',
        source: 'a(); // x\r\nb(); // y\nc();\r\n',
        comments: ['// x\r', '// y'],
      ),
    ];

    for (final testCase in cases) {
      test(testCase.name, () {
        expect(_comments(testCase.source), testCase.comments);
      });
    }

    test('a script has no characters: an apostrophe is only text, and a '
        'digraph is none', () {
      expect(_comments("// it's\nVALUE \"a\", \"b\" // c", cpp: false), [
        "// it's",
        '// c',
      ]);
      expect(_comments('a <% %> b', cpp: false), isEmpty);
    });

    test('inComment says whether an offset is in a comment', () {
      final scan = WindowsSourceScanner.scan('a // b\nc', path: _path);

      expect(scan.inComment(1), isFalse);
      expect(scan.inComment(2), isTrue);
      expect(scan.inComment(6), isFalse);
    });
  });

  group('WindowsSourceScanner rejects what it does not model', () {
    final cases = <({String name, String source, Pattern message})>[
      (
        name: 'a string that is not closed',
        source: 'a("x\nb();',
        message: 'not closed',
      ),
      (
        name: 'a character that is not closed',
        source: "a('x\nb();",
        message: 'not closed',
      ),
      (
        name: 'a block comment that is not closed',
        source: 'a /* x',
        message: 'not closed',
      ),
      (
        name: 'a raw string that is not closed',
        source: 'a(R"x(abc"x";',
        message: 'not closed',
      ),
      (
        name: 'a raw string with a delimiter that is too long',
        source: 'a(R"12345678901234567(x)12345678901234567");',
        message: 'raw string',
      ),
      (
        name: 'a raw string with a delimiter that has a space',
        source: 'a(R"a b(x)a b");',
        message: 'raw string',
      ),
      (
        name: 'a line continuation in code',
        source: '#define A \\\n  1\n',
        message: 'continuation',
      ),
      (
        name: 'a line continuation in code, with CRLF',
        source: '#define A \\\r\n  1\r\n',
        message: 'continuation',
      ),
      (
        name: 'a line continuation in a string',
        source: 'a("x\\\ny");',
        message: 'continuation',
      ),
      (
        name: 'a line continuation in a character',
        source: "a('\\\n');",
        message: 'continuation',
      ),
      (
        name: 'a line continuation after a block comment',
        source: '/* a */ \\\nb();',
        message: 'continuation',
      ),
      (
        name: 'a digraph for a brace',
        source: 'int f() <% return 1; %>',
        message: 'digraph',
      ),
      (
        name: 'a digraph for a bracket',
        source: 'a<:1:> = 1;',
        message: 'digraph',
      ),
      (
        name: 'a digraph for a hash',
        source: '%:define A 1\n',
        message: 'digraph',
      ),
      (
        name: 'an include of a source file',
        source: '#include "generated.inc"\n',
        message: '#include',
      ),
      (
        name: 'an include through a macro',
        source: '#define H "a.h"\n#include H\n',
        message: '#include',
      ),
      (
        name: 'an include of a cpp file',
        source: '  #  include <x.cpp>\n',
        message: '#include',
      ),
    ];

    for (final testCase in cases) {
      test(testCase.name, () {
        expect(
          () => WindowsSourceScanner.scan(testCase.source, path: _path),
          throwsA(
            isA<UnsupportedRunnerLayoutException>()
                .having((e) => e.path, 'path', _path)
                .having(
                  (e) => e.toString(),
                  'message',
                  allOf(
                    contains(testCase.message),
                    contains('Then run flavorizr again.'),
                  ),
                ),
          ),
        );
      });
    }

    test('a script is only checked for what it shares with C++', () {
      expect(
        () => WindowsSourceScanner.scan('a("x\n', path: _path, cpp: false),
        throwsA(isA<UnsupportedRunnerLayoutException>()),
      );
      expect(
        () => WindowsSourceScanner.scan(
          '#include "generated.inc"\n',
          path: _path,
          cpp: false,
        ),
        throwsA(isA<UnsupportedRunnerLayoutException>()),
      );
    });
  });
}
