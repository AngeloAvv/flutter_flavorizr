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
import 'package:flutter_test/flutter_test.dart';

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

    test('changes nothing but the title: line endings, a missing last line '
        'break and the rest of the file stay', () {
      final crlf = pristine.replaceAll('\n', '\r\n').trimRight();

      expect(edit(crlf), template.replaceAll('\n', '\r\n').trimRight());
    });

    test('templates every call that creates the window, in code', () {
      final two =
          '#if A\n  window.Create(L"a", origin, size)\n#else\n'
          '  window.Create(L"b", origin, size)\n#endif\n';

      expect(edit(two), two.replaceAll(RegExp('L"[ab]"'), 'L"@WINDOW_TITLE@"'));
    });

    test('does not look at a call that cannot be templated if it is in a '
        'comment', () {
      final source = '// window.Create(L"a\\"b", origin, size)\n$pristine';

      expect(
        edit(source),
        '// window.Create(L"a\\"b", origin, size)\n$template',
      );
    });

    test('does not look at a call in a comment', () {
      final source = '// window.Create(L"old", origin, size)\n$pristine';

      expect(edit(source), '// window.Create(L"old", origin, size)\n$template');
    });

    group('rejects what it cannot template with an actionable error', () {
      final cases = {
        'there is no call': 'int main() {}\n',
        'the call is only commented out':
            '// window.Create(L"old", origin, size)\n',
        'the title has an escaped quote':
            r'window.Create(L"My \"App\"", origin, size)',
        'the arguments are not the ones of Flutter':
            'window.Create(L"x", Point(1, 1), size)',
        'the title is not a wide literal': 'window.Create("x", origin, size)',
        'the title is a raw wide string':
            'window.Create(LR"(x)", origin, size)',
        'the title is a UTF-8 or UTF-16 literal':
            'window.Create(u8"x", origin, size)',
        'the title is a macro': 'window.Create(TITLE, origin, size)',
        'the title is empty and then something':
            'window.Create(L"" L"x", origin, size)',
        'the title is two literals': 'window.Create(L"a" L"b", origin, size)',
        'a call that is in a string': 'puts("window.Create(");\n',
        'a call with a space before the parenthesis':
            'window.Create (L"x", origin, size)',
        'a call through a pointer': 'window->Create(L"x", origin, size)',
        'one branch has a title that cannot be templated, the other a plain '
                'one':
            '#if ALT\n  window.Create(L"My \\"App\\"", origin, size);\n'
            '#else\n  window.Create(L"Default", origin, size);\n#endif\n',
        'the plain one comes first, the other one is a macro':
            'window.Create(L"Default", origin, size);\n'
            'window.Create(TITLE, origin, size);\n',
      };

      for (final MapEntry(key: name, value: source) in cases.entries) {
        test(name, () {
          expect(
            () => edit(source),
            _rejects('windows/runner/main.cpp', 'window.Create'),
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
    String edit(String source) =>
        WindowsRunnerRcTemplateEditor.template(source);

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

    test('changes nothing but those three values: line endings, a missing '
        'last line break and the rest of the file stay', () {
      final crlf = pristine.replaceAll('\n', '\r\n').trimRight();

      expect(edit(crlf), template.replaceAll('\n', '\r\n').trimRight());
    });

    test('does not look at an icon or a version entry in a comment', () {
      final source =
          '// IDI_APP_ICON ICON "resources\\\\old.ico"\n'
          '// VALUE "ProductName", "old" "\\0"\n$pristine';

      expect(
        edit(source),
        '// IDI_APP_ICON ICON "resources\\\\old.ico"\n'
        '// VALUE "ProductName", "old" "\\0"\n$template',
      );
    });

    test('templates every icon and entry that is in the file', () {
      final twice =
          '$pristine\n${pristine.substring(pristine.indexOf('IDI_APP_ICON'))}';

      expect('@RUNNER_APP_ICON@'.allMatches(edit(twice)), hasLength(2));
    });

    group('rejects what it cannot template with an actionable error', () {
      final cases = {
        'there is no icon': pristine.replaceFirst(
          'IDI_APP_ICON',
          'IDI_OTHER_ICON',
        ),
        'the icon is not in the resources folder': pristine.replaceFirst(
          r'"resources\\app_icon.ico"',
          '"app.ico"',
        ),
        'there is no file description': pristine.replaceFirst(
          '"FileDescription"',
          '"Other"',
        ),
        'there is no product name': pristine.replaceFirst(
          '"ProductName"',
          '"Other"',
        ),
        'a second icon is not one that can be templated':
            '$pristine\nIDI_APP_ICON ICON "app.ico"\n',
        'a second icon has a path with slashes':
            '$pristine\nIDI_APP_ICON ICON "resources/app_icon.ico"\n',
        'a second file description is a macro':
            '$pristine\n  VALUE "FileDescription", TITLE "\\0"\n',
        'a second product name has more than a string':
            '$pristine\n  VALUE "ProductName", "a" "b" "\\0"\n',
      };

      for (final MapEntry(key: name, value: source) in cases.entries) {
        test(name, () {
          expect(
            () => edit(source),
            _rejects('windows/runner/Runner.rc', RegExp('icon|entry')),
          );
        });
      }
    });
  });
}
