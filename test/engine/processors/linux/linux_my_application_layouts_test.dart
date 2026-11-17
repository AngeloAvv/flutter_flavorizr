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

import 'package:flutter_flavorizr/src/engine/processors/linux/linux_my_application_editor.dart';
import 'package:flutter_flavorizr/src/exception/malformed_resource_exception.dart';
import 'package:flutter_flavorizr/src/exception/unsafe_title_setter_exception.dart';
import 'package:flutter_test/flutter_test.dart';

/// What the editor has to do with a layout of the call that sets the title of
/// the window: put its region after it, or refuse it, which is an
/// [UnsafeTitleSetterException], or find nothing to flavor, which is a
/// [MalformedResourceException]. There is no other way: a layout the editor
/// cannot be sure about is never guessed.
enum _Outcome { flavored, unsafe, nothing }

typedef _Layout = (String name, String setter, _Outcome outcome);

/// A layout of the whole file, and the region that is expected in it.
typedef _Source = (String name, String source, _Outcome outcome, String region);

const _titles = {'apple': 'Apple App', 'banana': 'Banana App'};

/// The call, as `flutter create` writes it.
const _call = '    gtk_window_set_title(window, "example");\n';

final _pristine = File(
  'test_resources/linux/my_application_processor_test/my_application.cc',
).readAsStringSync();

/// Whether [offset] of [text] is in a comment, which strings, that can have
/// the marks of one, are not.
bool _inComment(String text, int offset) =>
    RegExp(
          r'//(?:\\\r?\n|[^\n])*|/\*[\s\S]*?\*/|"(?:[^"\\\n]|\\.)*"|'
          r"'(?:[^'\\\n]|\\.)*'",
        )
        .allMatches(text)
        .any(
          (match) =>
              match.start <= offset &&
              offset < match.end &&
              match[0]!.startsWith('/'),
        );

final _layouts = <_Layout>[
  // Comments.
  (
    'line comment above',
    '    // gtk_window_set_title(window, "old");\n$_call',
    _Outcome.flavored,
  ),
  (
    'line comment continued by a backslash',
    '    // old \\\n    gtk_window_set_title(window, "old");\n$_call',
    _Outcome.flavored,
  ),
  (
    'trailing line comment',
    '    gtk_window_set_title(window, "example"); // Base title\n',
    _Outcome.flavored,
  ),
  (
    'trailing block comment closed on the line',
    '    gtk_window_set_title(window, "example"); /* Base title */\n',
    _Outcome.flavored,
  ),
  (
    'trailing block comment open past the line',
    '    gtk_window_set_title(window, "example"); /* Base title\n       explanation */\n',
    _Outcome.unsafe,
  ),
  (
    'block comment open past the line, then more code',
    '    gtk_window_set_title(window, "example"); /* a\n       b */ foo();\n',
    _Outcome.unsafe,
  ),
  (
    'multi-line block comment above',
    '    /*\n    gtk_window_set_title(window, "old");\n    */\n$_call',
    _Outcome.flavored,
  ),
  (
    'comment between an if header and the statement',
    '    if (a)\n    /* c */\n$_call',
    _Outcome.unsafe,
  ),
  (
    'comment marks inside strings',
    '    const char* a = "/* not";\n    const char* b = "*/ // no";\n$_call',
    _Outcome.flavored,
  ),
  // Preprocessor.
  ('inside #if', '#if defined(A)\n$_call#endif\n', _Outcome.flavored),
  (
    'inside a directive continued over lines',
    '#if defined(A) \\\n    || defined(B)\n$_call#endif\n',
    _Outcome.flavored,
  ),
  (
    'after #else',
    '#ifdef A\n    foo();\n#else\n$_call#endif\n',
    _Outcome.flavored,
  ),
  (
    'a #define that spans lines and has the call',
    '#define SET_TITLE() \\\n  gtk_window_set_title(window, "macro");\n$_call',
    _Outcome.flavored,
  ),
  (
    'a #define right after an if header',
    '    if (a)\n#define X 1\n$_call',
    _Outcome.unsafe,
  ),
  // Control flow.
  ('braced if', '    if (a) {\n  $_call    }\n', _Outcome.flavored),
  (
    'else if chain with braces',
    '    if (a) {\n      foo();\n    } else if (b) {\n  $_call    }\n',
    _Outcome.flavored,
  ),
  (
    'after a block that closed',
    '    if (a) {\n      foo();\n    }\n$_call',
    _Outcome.flavored,
  ),
  ('unbraced if', '    if (a)\n  $_call', _Outcome.unsafe),
  ('unbraced else', '    if (a) {\n    } else\n  $_call', _Outcome.unsafe),
  (
    'unbraced else if',
    '    if (a) {\n    } else if (b)\n  $_call',
    _Outcome.unsafe,
  ),
  ('unbraced for', '    for (;;)\n  $_call', _Outcome.unsafe),
  ('unbraced while', '    while (a)\n  $_call', _Outcome.unsafe),
  ('unbraced do', '    do\n  $_call    while (0);\n', _Outcome.unsafe),
  (
    'a condition over several lines',
    '    if (a &&\n        b)\n  $_call',
    _Outcome.unsafe,
  ),
  ('after a label', '    done:\n  $_call', _Outcome.unsafe),
  (
    'after a case',
    '    switch (a) {\n    case 1:\n  $_call    }\n',
    _Outcome.unsafe,
  ),
  (
    'after default',
    '    switch (a) {\n    default:\n  $_call    }\n',
    _Outcome.unsafe,
  ),
  (
    'if and call on one line',
    '    if (a) gtk_window_set_title(window, "example");\n',
    _Outcome.unsafe,
  ),
  (
    'braces and call on one line',
    '    if (a) { gtk_window_set_title(window, "example"); }\n',
    _Outcome.unsafe,
  ),
  (
    'another statement on the line',
    '    gtk_window_set_title(window, "example"); foo();\n',
    _Outcome.unsafe,
  ),
  // Strings.
  (
    'escapes in the literal',
    '    gtk_window_set_title(window, "a \\"quoted\\" \\\\ b");\n',
    _Outcome.flavored,
  ),
  (
    'adjacent literals',
    '    gtk_window_set_title(window, "a" "b");\n',
    _Outcome.flavored,
  ),
  (
    'a semicolon and slashes in the literal',
    '    gtk_window_set_title(window, "a; // b /* c");\n',
    _Outcome.flavored,
  ),
  (
    'a string that looks like control flow before',
    '    const char* s = "if (x)";\n$_call',
    _Outcome.flavored,
  ),
  (
    'a raw string with the call',
    '    const char* r = R"x(gtk_window_set_title(window, "old"); )x";\n$_call',
    _Outcome.flavored,
  ),
  (
    'a character literal with a quote',
    "    char q = '\"';\n$_call",
    _Outcome.flavored,
  ),
  // The call itself.
  (
    'the window cast with GTK_WINDOW',
    '    gtk_window_set_title(GTK_WINDOW(window), "example");\n',
    _Outcome.flavored,
  ),
  (
    'the cast with spaces',
    '    gtk_window_set_title( GTK_WINDOW (window) , "example");\n',
    _Outcome.flavored,
  ),
  (
    'arguments over several lines',
    '    gtk_window_set_title(\n        window,\n        "example");\n',
    _Outcome.flavored,
  ),
  (
    'extra whitespace',
    '    gtk_window_set_title  (  window ,"example" )  ;\n',
    _Outcome.flavored,
  ),
  (
    'a newline before the parenthesis',
    '    gtk_window_set_title\n    (window, "example");\n',
    _Outcome.flavored,
  ),
];

String _region(String name) =>
    '// ----- BEGIN $name (autogenerated by flutter_flavorizr) -----';

/// What the editor does with [source], and what has to hold when it flavors it.
void _expectOutcome(String source, _Outcome outcome, String region) {
  if (outcome != _Outcome.flavored) {
    expect(
      () => LinuxMyApplicationEditor.withWindowTitles(source, _titles),
      throwsA(
        outcome == _Outcome.unsafe
            ? isA<UnsafeTitleSetterException>()
            : isA<MalformedResourceException>(),
      ),
    );

    return;
  }

  final patched = LinuxMyApplicationEditor.withWindowTitles(source, _titles);
  final at = patched.indexOf(_region(region));

  expect(at, isNonNegative, reason: 'the region $region');
  expect(
    _inComment(patched, patched.indexOf('#ifdef', at)),
    isFalse,
    reason: 'the region is code, not part of a comment',
  );
  expect(
    LinuxMyApplicationEditor.withWindowTitles(patched, _titles),
    patched,
    reason: 'a second run changes nothing',
  );
  // Whatever is outside the regions is as the user wrote it.
  expect(
    patched.replaceAll(
      RegExp(r'[ \t]*// ----- BEGIN [\s\S]*?// ----- END [^\n]*\n'),
      '',
    ),
    source,
  );
}

/// The file, with `window_title` declared by [declaration] and both setters
/// reading it.
String _reading(String declaration) => _pristine
    .replaceFirst(
      '  if (use_header_bar) {\n',
      '  $declaration window_title = "example";\n  if (use_header_bar) {\n',
    )
    .replaceFirst(
      'gtk_header_bar_set_title(header_bar, "example");',
      'gtk_header_bar_set_title(header_bar, window_title);',
    )
    .replaceFirst(
      'gtk_window_set_title(window, "example");',
      'gtk_window_set_title(window, window_title);',
    );

final _sources = <_Source>[
  // The declaration of the variable: it has to be one that can be assigned.
  (
    'a mutable pointer',
    _reading('const gchar*'),
    _Outcome.flavored,
    'window_title',
  ),
  (
    'spaces around the star',
    _reading('const  gchar  *'),
    _Outcome.flavored,
    'window_title',
  ),
  ('constexpr', _reading('constexpr const gchar*'), _Outcome.unsafe, ''),
  ('a constant pointer', _reading('const gchar* const'), _Outcome.unsafe, ''),
  ('static', _reading('static const gchar*'), _Outcome.unsafe, ''),
  ('a pointer to something else', _reading('const char*'), _Outcome.unsafe, ''),
  ('a pointer that is not to const', _reading('gchar*'), _Outcome.unsafe, ''),
  (
    'an unbraced if before the declaration',
    _reading('if (a)\n    const gchar*'),
    _Outcome.unsafe,
    '',
  ),
  (
    'a qualifier that nothing reads',
    _pristine.replaceFirst(
      '  if (use_header_bar) {\n',
      '  constexpr const gchar* window_title = "x";\n  if (use_header_bar) {\n',
    ),
    _Outcome.flavored,
    'header_bar_title',
  ),
  // How many there are of each.
  (
    'two declarations',
    _reading('const gchar*').replaceFirst(
      '  if (use_header_bar) {\n',
      '  const gchar* window_title = "again";\n  if (use_header_bar) {\n',
    ),
    _Outcome.unsafe,
    '',
  ),
  (
    'a declaration in a comment',
    _reading('const gchar*').replaceFirst(
      '  if (use_header_bar) {\n',
      '  // const gchar* window_title = "old";\n  if (use_header_bar) {\n',
    ),
    _Outcome.flavored,
    'window_title',
  ),
  (
    'two window setters, one for each branch',
    _pristine.replaceFirst(
      '  if (use_header_bar) {\n',
      '  if (use_header_bar) {\n    gtk_window_set_title(window, "first");\n',
    ),
    _Outcome.unsafe,
    '',
  ),
  (
    'two header bar setters',
    _pristine.replaceFirst(
      '    gtk_header_bar_set_title(header_bar, "example");\n',
      '    gtk_header_bar_set_title(header_bar, "example");\n    gtk_header_bar_set_title(header_bar, "again");\n',
    ),
    _Outcome.unsafe,
    '',
  ),
  (
    'a second window setter that casts the window',
    _pristine.replaceFirst(
      '  if (use_header_bar) {\n',
      '  if (use_header_bar) {\n'
          '    gtk_window_set_title(GTK_WINDOW(window), "again");\n',
    ),
    _Outcome.unsafe,
    '',
  ),
  (
    'a second window setter in a comment',
    _pristine.replaceFirst(
      '  if (use_header_bar) {\n',
      '  // gtk_window_set_title(window, "old");\n  if (use_header_bar) {\n',
    ),
    _Outcome.flavored,
    'plain_window_title',
  ),
  (
    'a setter that is not a literal next to one that is',
    _pristine.replaceFirst(
      '  if (use_header_bar) {\n',
      '  gtk_window_set_title(window, custom_title);\n  if (use_header_bar) {\n',
    ),
    _Outcome.flavored,
    'plain_window_title',
  ),
  ('no setter and no declaration', 'int main() {}\n', _Outcome.nothing, ''),
  (
    'only setters that are not literals',
    _pristine.replaceAll('"example"', 'custom_title'),
    _Outcome.nothing,
    '',
  ),
  (
    'a variable that nothing reads and no literal setter',
    _reading('const gchar*').replaceAll('window_title);', 'custom_title);'),
    _Outcome.nothing,
    '',
  ),
];

void main() {
  group('LinuxMyApplicationEditor layouts of the call that sets the title', () {
    for (final (name, setter, outcome) in _layouts) {
      test('$name: ${outcome.name}', () {
        _expectOutcome(
          _pristine.replaceFirst(_call, setter),
          outcome,
          'plain_window_title',
        );
      });
    }
  });

  group('LinuxMyApplicationEditor layouts of the whole file', () {
    for (final (name, source, outcome, region) in _sources) {
      test(
        '$name: ${outcome.name}',
        () => _expectOutcome(source, outcome, region),
      );
    }
  });

  group('LinuxMyApplicationEditor form of the call in the region of the '
      'window', () {
    String windowRegion(String patched) => RegExp(
      r'BEGIN plain_window_title[\s\S]*?END plain_window_title',
    ).firstMatch(patched)![0]!;

    const cast = '    gtk_window_set_title(GTK_WINDOW(window), "example");\n';

    test('a setter that casts the window gets a region that casts it', () {
      for (final setter in [
        cast,
        '    gtk_window_set_title( GTK_WINDOW (window) , "example");\n',
      ]) {
        final source = _pristine.replaceFirst(_call, setter);

        final patched = LinuxMyApplicationEditor.withWindowTitles(
          source,
          _titles,
        );

        expect(
          windowRegion(patched),
          allOf(
            contains('gtk_window_set_title(GTK_WINDOW(window), "Apple App");'),
            contains('gtk_window_set_title(GTK_WINDOW(window), "Banana App");'),
            isNot(contains('gtk_window_set_title(window,')),
          ),
          reason: setter,
        );
        expect(
          LinuxMyApplicationEditor.withWindowTitles(patched, _titles),
          patched,
        );
      }
    });

    test('a setter that does not cast it keeps the region 2.x wrote, byte for '
        'byte', () {
      final patched = LinuxMyApplicationEditor.withWindowTitles(
        _pristine,
        _titles,
      );

      expect(
        windowRegion(patched),
        allOf(
          contains('gtk_window_set_title(window, "Apple App");'),
          isNot(contains('GTK_WINDOW')),
        ),
      );
    });

    test('a window that is a GtkWidget* is cast in the region too', () {
      final source = _pristine
          .replaceFirst('GtkWindow* window', 'GtkWidget* window')
          .replaceFirst(_call, cast);

      final patched = LinuxMyApplicationEditor.withWindowTitles(
        source,
        _titles,
      );

      expect(source, contains('GtkWidget* window'));
      expect(
        windowRegion(patched),
        contains('gtk_window_set_title(GTK_WINDOW(window), "Apple App");'),
      );
    });

    test('a region that was written without the cast follows a setter that '
        'has it', () {
      final flavorized = LinuxMyApplicationEditor.withWindowTitles(
        _pristine,
        _titles,
      );
      final cased = flavorized.replaceFirst(_call, cast);

      final patched = LinuxMyApplicationEditor.withWindowTitles(cased, _titles);

      expect(
        windowRegion(patched),
        contains('gtk_window_set_title(GTK_WINDOW(window), "Apple App");'),
      );
      expect(
        LinuxMyApplicationEditor.withWindowTitles(patched, _titles),
        patched,
      );
    });
  });
}
