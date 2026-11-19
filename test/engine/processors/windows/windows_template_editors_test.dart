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

import 'package:flutter_flavorizr/src/engine/processors/windows/windows_template_editors.dart';
import 'package:flutter_flavorizr/src/exception/unsupported_runner_layout_exception.dart';
import 'package:test/test.dart';

String _read(String path) =>
    File('test_resources/windows/$path').readAsStringSync();

Matcher _rejects(String path, Pattern message) => throwsA(
  isA<UnsupportedRunnerLayoutException>()
      .having((e) => e.path, 'path', path)
      .having(
        (e) => e.toString(),
        'message',
        allOf(contains(message), contains('Then run flavorizr again.')),
      ),
);

/// The line endings of every other line of [text] are CRLF.
String _mixed(String text) {
  final lines = text.split('\n');

  return [
    for (final (index, line) in lines.indexed)
      index.isEven && index < lines.length - 1 ? '$line\r' : line,
  ].join('\n');
}

void main() {
  group('WindowsMainCppTemplateEditor', () {
    final pristine = _read('main_cpp_title_processor_test/main.cpp');
    final template = _read('main_cpp_title_processor_test/main_expected.cpp');
    String edit(String source) => WindowsMainCppTemplateEditor.template(source);

    test('is the 2.x template of the pristine file of Flutter', () {
      expect(edit(pristine), template);
      expect(
        template,
        contains('window.Create(L"@WINDOW_TITLE@", origin, size)'),
      );
    });

    test('templates a file that already has the title of a flavor, which '
        'is what a 2.x build left in the source dir', () {
      expect(
        edit(pristine.replaceFirst('L"example"', 'L"Apple App"')),
        template,
      );
    });

    test('is the same for a template', () {
      expect(edit(template), template);
    });

    test('changes nothing but the title: line endings (LF, CRLF or both) and '
        'a missing last line break stay', () {
      final crlf = pristine.replaceAll('\n', '\r\n').trimRight();

      expect(edit(crlf), template.replaceAll('\n', '\r\n').trimRight());
      expect(edit(_mixed(pristine)), _mixed(template));
    });

    test('templates every call, each on a line of its own, whatever branch of '
        'an #if it is in', () {
      const two =
          '#if A\n  window.Create(L"a", origin, size)\n#else\n'
          '  if (!window.Create(L"b", origin, size)) {\n#endif\n';

      expect(edit(two), two.replaceAll(RegExp('L"[ab]"'), 'L"@WINDOW_TITLE@"'));
    });

    test('templates a call that is on a line of its own even where it is in a '
        'comment, since it is the same as the others and does no harm', () {
      const call = 'window.Create(L"a", origin, size);';

      expect(
        edit('/*\n$call\n*/\n$pristine'),
        '/*\nwindow.Create(L"@WINDOW_TITLE@", origin, size);\n*/\n$template',
      );
    });

    group('rejects anything that mentions what it edits, and is not what it '
        'recognises, with an actionable error', () {
      const call = 'window.Create(L"a", origin, size);';
      final cases = <String, (String, Pattern)>{
        'there is no call': ('int main() {}\n', 'window.Create'),
        'the call is only in a line comment': ('// $call\n', 'window.Create'),
        'a line comment before the call': (
          '// $call\n$pristine',
          'window.Create',
        ),
        'a block comment before the call': (
          '/* $call */\n$pristine',
          'window.Create',
        ),
        'a call after a block comment on its line': (
          '/* old */ $call\n',
          'window.Create',
        ),
        'a call after other code on its line': (
          'int a; $call\n',
          'window.Create',
        ),
        'two calls on one line': ('$call $call\n', 'window.Create'),
        'a title with // and another call on the line': (
          'if (alt) window.Create(L"https://a", origin, size); '
              'else window.Create(L"B", origin, size);',
          'window.Create',
        ),
        'a call after a character literal with a quote': (
          'char q = \'"\'; $call\n',
          'window.Create',
        ),
        'a call after a string with an escaped quote': (
          r'puts("a\"//"); '
              '$call\n',
          'window.Create',
        ),
        'a call in a string': (
          'puts("window.Create(");\n$pristine',
          'window.Create',
        ),
        'a call in a raw string': (
          'auto help = R"(window.Create(L"example", origin, size))";\n$pristine',
          'window.Create',
        ),
        'the title has an escaped quote': (
          r'window.Create(L"My \"App\"", origin, size)',
          'window.Create',
        ),
        'the arguments are not the ones of Flutter': (
          'window.Create(L"x", Point(1, 1), size)',
          'window.Create',
        ),
        'the title is not a wide literal': (
          'window.Create("x", origin, size)',
          'window.Create',
        ),
        'the title is a raw wide string': (
          'window.Create(LR"(x)", origin, size)',
          'window.Create',
        ),
        'the title is a UTF-8 or UTF-16 literal': (
          'window.Create(u8"x", origin, size)',
          'window.Create',
        ),
        'the title is a macro': (
          'window.Create(TITLE, origin, size)',
          'window.Create',
        ),
        'the title is empty and then something': (
          'window.Create(L"" L"x", origin, size)',
          'window.Create',
        ),
        'the title is two literals': (
          'window.Create(L"a" L"b", origin, size)',
          'window.Create',
        ),
        'a space before the parenthesis': (
          'window.Create (L"x", origin, size)',
          'window.Create',
        ),
        'a call through a pointer': (
          'window->Create(L"x", origin, size)',
          'window.Create',
        ),
        'one branch has a title that cannot be templated, the other a plain '
            'one': (
          '#if ALT\n  window.Create(L"My \\"App\\"", origin, size);\n'
              '#else\n  window.Create(L"Default", origin, size);\n#endif\n',
          'window.Create',
        ),
        'the plain one comes first, the other one is a macro': (
          'window.Create(L"Default", origin, size);\n'
              'window.Create(TITLE, origin, size);\n',
          'window.Create',
        ),
        'an include after a comment': (
          '/* generated */ #include "generated.inc"\n$pristine',
          '#include',
        ),
        'an include of a source file': (
          '#include "generated.inc"\n$pristine',
          '#include',
        ),
        'an include through a macro': (
          '#define H "a.h"\n#include H\n$pristine',
          '#include',
        ),
        'an include in a comment': ('// #include "a.h"\n$pristine', '#include'),
        'a digraph for #': ('%:include "a.inc"\n$pristine', 'digraph'),
        'a line continuation in a macro': (
          '#define A \\\n  1\n$pristine',
          'continuation',
        ),
        'a line continuation in a comment': (
          '// a \\\n$pristine',
          'continuation',
        ),
        'a line continuation in a string, with CRLF': (
          'a("x\\\r\ny");\n$pristine',
          'continuation',
        ),
      };

      for (final MapEntry(key: name, value: (source, message))
          in cases.entries) {
        test(name, () {
          expect(
            () => edit(source),
            _rejects('windows/runner/main.cpp', message),
          );
        });
      }
    });
  });

  group('WindowsRunnerRcTemplateEditor', () {
    final pristine = _read('runner_rc_content_processor_test/Runner.rc');
    final template = _read(
      'runner_rc_content_processor_test/Runner_expected.rc',
    );
    String edit(String source, {List<String> titles = const []}) =>
        WindowsRunnerRcTemplateEditor.template(source, titles: titles);

    test('is the 2.x template of the pristine file of Flutter', () {
      expect(edit(pristine), template);
      expect(template, contains(r'"resources\\@RUNNER_APP_ICON@"'));
      expect('@WINDOW_TITLE@'.allMatches(template), hasLength(2));
    });

    test('templates a file that has the icon and the title of a flavor, which '
        'is what a 2.x build left in the source dir', () {
      final built = pristine
          .replaceFirst(r'resources\\app_icon.ico', r'resources\\apple.ico')
          .replaceFirst(
            'VALUE "FileDescription", "example"',
            'VALUE "FileDescription", "Apple App"',
          )
          .replaceFirst(
            'VALUE "ProductName", "example"',
            'VALUE "ProductName", "Apple App"',
          );

      expect(built, isNot(pristine));
      expect(edit(built), template);
    });

    test('is the same for a template', () {
      expect(edit(template), template);
    });

    test('changes nothing but those three values: line endings (LF, CRLF or '
        'both) and a missing last line break stay', () {
      final crlf = pristine.replaceAll('\n', '\r\n').trimRight();

      expect(edit(crlf), template.replaceAll('\n', '\r\n').trimRight());
      expect(edit(_mixed(pristine)), _mixed(template));
    });

    test('is not taken in by a // that is in a string of the entries before '
        'the one it templates', () {
      final source = pristine.replaceFirst(
        'VALUE "CompanyName", "com.example"',
        'VALUE "CompanyName", "http://example.com"',
      );

      expect(source, isNot(pristine));
      expect(
        edit(source),
        template.replaceFirst(
          'VALUE "CompanyName", "com.example"',
          'VALUE "CompanyName", "http://example.com"',
        ),
      );
    });

    test('templates every icon and entry that is in the file, when each is '
        'one that it recognises', () {
      final twice =
          '$pristine\n${pristine.substring(pristine.indexOf('IDI_APP_ICON'))}';

      expect('@RUNNER_APP_ICON@'.allMatches(edit(twice)), hasLength(2));
    });

    group('a title that is not ASCII needs one UTF-8 code page', () {
      const directive = '#pragma code_page(65001)';

      test('is fine in a file that has the directive', () {
        expect(pristine, contains(directive));
        expect(edit(pristine, titles: ['Café', 'Apple']), template);
      });

      test('is rejected by a file that has no directive, another one, one in '
          'a comment, or another after it', () {
        for (final source in [
          pristine.replaceFirst(directive, ''),
          pristine.replaceFirst(directive, '#pragma code_page(1252)'),
          pristine.replaceFirst(directive, '// $directive'),
          pristine.replaceFirst(directive, '/* $directive */'),
          pristine.replaceFirst(
            directive,
            '$directive\n#pragma code_page(1252)',
          ),
          pristine.replaceFirst(directive, '$directive\n$directive'),
        ]) {
          expect(source, isNot(pristine));
          expect(
            () => edit(source, titles: ['Apple', 'Café']),
            _rejects('windows/runner/Runner.rc', 'code_page'),
          );
        }
      });

      test('does not matter for ASCII titles', () {
        expect(
          edit(
            pristine.replaceFirst(directive, '#pragma code_page(1252)'),
            titles: ['Apple'],
          ),
          template.replaceFirst(directive, '#pragma code_page(1252)'),
        );
      });
    });

    group('rejects anything that mentions what it edits, and is not what it '
        'recognises, with an actionable error', () {
      final cases = <String, (String, Pattern)>{
        'there is no icon': (
          pristine.replaceFirst('IDI_APP_ICON', 'IDI_OTHER_ICON'),
          'IDI_APP_ICON',
        ),
        'the icon is not in the resources folder': (
          pristine.replaceFirst(r'"resources\\app_icon.ico"', '"app.ico"'),
          'IDI_APP_ICON',
        ),
        'there is no file description': (
          pristine.replaceFirst('"FileDescription"', '"Other"'),
          'FileDescription',
        ),
        'there is no product name': (
          pristine.replaceFirst('"ProductName"', '"Other"'),
          'ProductName',
        ),
        'a second icon is not one that can be templated': (
          '$pristine\nIDI_APP_ICON ICON "app.ico"\n',
          'IDI_APP_ICON',
        ),
        'a second icon has a path with slashes': (
          '$pristine\nIDI_APP_ICON ICON "resources/app_icon.ico"\n',
          'IDI_APP_ICON',
        ),
        'a second file description is a macro': (
          '$pristine\n  VALUE "FileDescription", TITLE "\\0"\n',
          'FileDescription',
        ),
        'a second product name has more than a string': (
          '$pristine\n  VALUE "ProductName", "a" "b" "\\0"\n',
          'ProductName',
        ),
        'an icon in a line comment': (
          '// IDI_APP_ICON ICON "resources\\\\old.ico"\n$pristine',
          'IDI_APP_ICON',
        ),
        'an entry in a line comment': (
          '// VALUE "ProductName", "old" "\\0"\n$pristine',
          'ProductName',
        ),
        'an icon and an entry in a block comment': (
          '/* a comment\nIDI_APP_ICON ICON "bad"\nVALUE "ProductName", TITLE "\\0"\n*/\n$pristine',
          'IDI_APP_ICON',
        ),
        'a mention in a string': (
          'x "FileDescription"\n$pristine',
          'FileDescription',
        ),
        'an include of a script': (
          '#include "other.rc"\n$pristine',
          '#include',
        ),
        'an include after a comment': (
          '/* a */ #include "other.rc"\n$pristine',
          '#include',
        ),
        'a line continuation': ('#define A \\\n 1\n$pristine', 'continuation'),
      };

      for (final MapEntry(key: name, value: (source, message))
          in cases.entries) {
        test(name, () {
          expect(
            () => edit(source),
            _rejects('windows/runner/Runner.rc', message),
          );
        });
      }
    });
  });
}
