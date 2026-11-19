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

import 'package:flutter_flavorizr/src/engine/processors/windows/windows_runner_cmake_lists_editor.dart';
import 'package:flutter_flavorizr/src/engine/processors/windows/windows_template_editors.dart';
import 'package:flutter_flavorizr/src/exception/unsupported_runner_layout_exception.dart';
import 'package:test/test.dart';

String _read(String path) =>
    File('test_resources/windows/$path').readAsStringSync();

/// Where a mention is put in a file, and what it is wrapped in: anywhere, in a
/// comment, in a string, in a raw string, in the middle of a line.
final _wrappers = <String, String Function(String)>{
  'on a line of its own': (token) => '$token\n',
  'in a line comment': (token) => '// $token\n',
  'in a block comment': (token) => '/* $token */\n',
  'after a block comment': (token) => '/* x */ $token\n',
  'in a string': (token) => 'auto s = "${token.replaceAll('"', r'\"')}";\n',
  'in a raw string': (token) => 'auto s = R"($token)";\n',
  'in the middle of a line': (token) => 'int a; $token int b;\n',
  'in a CMake comment': (token) => '# $token\n',
  'in a CMake string': (token) => 'message("$token")\n',
};

/// Each position of [text] where something may be put: the start, the end and
/// the start of every line.
Iterable<int> _positions(String text) => {
  0,
  text.length,
  for (final (index, char) in text.split('').indexed)
    if (char == '\n') index + 1,
};

String _insert(String text, int at, String what) =>
    '${text.substring(0, at)}$what${text.substring(at)}';

void main() {
  // For each file, what it is edited with, the mentions the editor guards, and
  // what a guarded mention that is still in the output must look like.
  final main = _read('main_cpp_title_processor_test/main.cpp');
  final rc = _read('runner_rc_content_processor_test/Runner.rc');
  final cmake = _read('runner_cmake_lists_processor_test/CMakeLists.txt');

  group('an extra mention of a guarded token, wherever it is', () {
    test('in main.cpp is rejected, or templated like the others', () {
      final mentions = [
        'window.Create(L"x", origin, size)',
        'window.Create(TITLE, origin, size)',
        'window->Create(L"x", origin, size)',
        '#include "generated.inc"',
        '#include "a.h"',
        '%:include "a.inc"',
        'int a = 1; \\',
      ];
      final guarded = RegExp(r'window\s*(?:\.|->)\s*Create');
      var rejected = 0;

      for (final mention in mentions) {
        for (final wrap in _wrappers.values) {
          for (final at in _positions(main)) {
            final source = _insert(main, at, wrap(mention));

            try {
              final template = WindowsMainCppTemplateEditor.template(source);

              // It went through: no call is left with the title it had.
              for (final call in guarded.allMatches(template)) {
                expect(
                  template
                      .substring(call.start)
                      .startsWith(
                        RegExp(
                          r'window\s*(?:\.|->)\s*Create\(L"@WINDOW_TITLE@"',
                        ),
                      ),
                  isTrue,
                  reason: source,
                );
              }
              expect(
                RegExp(r'#\s*include|%:').allMatches(template).length,
                RegExp(r'#\s*include').allMatches(main).length +
                    (mention.startsWith('#include "a.h"') ? 1 : 0),
                reason: source,
              );
            } on UnsupportedRunnerLayoutException {
              rejected++;
            }
          }
        }
      }

      expect(rejected, greaterThan(0));
    });

    test('in Runner.rc is rejected, or templated like the others', () {
      final mentions = [
        'IDI_APP_ICON ICON "resources\\\\x.ico"',
        'IDI_APP_ICON ICON "x.ico"',
        'VALUE "FileDescription", "x" "\\0"',
        'VALUE "ProductName", TITLE "\\0"',
        'FileDescription',
        '#pragma code_page(1252)',
        '#include "generated.inc"',
      ];
      var rejected = 0;

      for (final mention in mentions) {
        for (final wrap in _wrappers.values) {
          for (final at in _positions(rc)) {
            final source = _insert(rc, at, wrap(mention));

            try {
              final template = WindowsRunnerRcTemplateEditor.template(
                source,
                titles: ['Café'],
              );

              expect(
                RegExp('IDI_APP_ICON').allMatches(template).length,
                RegExp(
                  r'IDI_APP_ICON[ \t]+ICON[ \t]+"resources\\\\@RUNNER_APP_ICON@"',
                ).allMatches(template).length,
                reason: source,
              );
              for (final name in ['FileDescription', 'ProductName']) {
                expect(
                  RegExp(name).allMatches(template).length,
                  RegExp(
                    '$name", "@WINDOW_TITLE@"',
                  ).allMatches(template).length,
                  reason: '$name in $source',
                );
              }
              expect(
                RegExp('code_page').allMatches(template).length,
                1,
                reason: source,
              );
            } on UnsupportedRunnerLayoutException {
              rejected++;
            }
          }
        }
      }

      expect(rejected, greaterThan(0));
    });

    test('in CMakeLists.txt is rejected, or leaves one call and no mention '
        'of the entrypoints but the lines that list them', () {
      final mentions = [
        r'add_executable(${BINARY_NAME} WIN32',
        'add_executable(other main.cpp)',
        'target_sources(\${BINARY_NAME} PRIVATE "main.cpp")',
        'set_property(TARGET x APPEND PROPERTY SOURCES Runner.rc)',
        'main.cpp',
        './Runner.rc',
        'custom\\).cpp',
        '#[[ )',
        'set(A "[[")',
        'x \\',
      ];
      var rejected = 0;

      for (final mention in mentions) {
        for (final wrap in _wrappers.values) {
          for (final at in _positions(cmake)) {
            final source = _insert(cmake, at, wrap(mention));

            try {
              final patched = WindowsRunnerCMakeListsEditor.withFlavors(
                source,
                {'apple': 'Apple'},
              );
              final outside = patched.replaceAll(
                RegExp(
                  '# ----- BEGIN FLUTTER_APP_FLAVOR.*?END FLUTTER_APP_FLAVOR[^\\n]*',
                  dotAll: true,
                ),
                '',
              );

              expect(
                RegExp(
                  'add_executable',
                  caseSensitive: false,
                ).allMatches(outside).length,
                1,
                reason: source,
              );
              // Every mention of an entrypoint is a line that lists it.
              expect(
                RegExp(r'main\.cpp|Runner\.rc').allMatches(outside).length,
                outside
                    .split('\n')
                    .where(
                      (line) => RegExp(
                        r'^\s*"?(\$\{CMAKE_CURRENT_SOURCE_DIR\}/)?'
                        r'(main\.cpp|Runner\.rc)"?\s*$',
                      ).hasMatch(line),
                    )
                    .length,
                reason: source,
              );
              expect(outside, isNot(contains('[[')), reason: source);
            } on UnsupportedRunnerLayoutException {
              rejected++;
            }
          }
        }
      }

      expect(rejected, greaterThan(0));
    });
  });
}
