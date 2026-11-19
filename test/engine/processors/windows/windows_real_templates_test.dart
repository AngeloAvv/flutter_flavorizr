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
import 'package:test/test.dart';
import 'package:path/path.dart' as p;

const _suffix = 'packages/flutter_tools/templates/app/windows.tmpl/runner';

/// The runner templates of the Flutter SDKs that are on this machine: the one
/// the tests run with, and the ones of FVM. Where there is none the group is
/// skipped.
Map<String, Directory> _runners() {
  final home = Platform.environment['HOME'] ?? '';
  final sdks = {
    ?Platform.environment['FLUTTER_ROOT'],
    if (home.isNotEmpty && Directory('$home/fvm/versions').existsSync())
      for (final dir in Directory('$home/fvm/versions').listSync())
        if (dir is Directory) dir.path,
  };

  return {
    for (final sdk in sdks)
      if (Directory(p.join(sdk, _suffix)).existsSync())
        p.basename(sdk): Directory(p.join(sdk, _suffix)),
  };
}

/// What `flutter create` writes for [template], a file of the templates of
/// Flutter, as a project called `my_app` of the organization `com.example`.
String _render(Directory runner, String template) =>
    File(p.join(runner.path, template))
        .readAsStringSync()
        .replaceAll('{{projectName}}', 'my_app')
        .replaceAll('{{organization}}', 'com.example')
        .replaceAll('{{year}}', '2026');

void main() {
  final runners = _runners();

  group('the runner that flutter create writes', () {
    test(
      'is found, or the tests below do not run',
      () {
        if (runners.isEmpty) {
          markTestSkipped('No Flutter SDK with the Windows templates here.');
        }
      },
      skip: runners.isEmpty
          ? 'No Flutter SDK with the Windows templates'
          : false,
    );

    for (final MapEntry(key: sdk, value: runner) in runners.entries) {
      group(sdk, () {
        test('CMakeLists.txt gets the region right after add_executable, and '
            'is up to date after it', () {
          final source = File(
            p.join(runner.path, 'CMakeLists.txt'),
          ).readAsStringSync();
          final patched = WindowsRunnerCMakeListsEditor.withFlavors(source, {
            'apple': 'Apple App',
          });
          final lines = patched.split('\n');
          final begin = lines.indexWhere(
            (line) => line.contains('BEGIN FLUTTER_APP_FLAVOR'),
          );

          expect(lines[begin - 1], ')');
          expect(
            patched.indexOf(r'add_executable(${BINARY_NAME} WIN32'),
            lessThan(patched.indexOf('BEGIN FLUTTER_APP_FLAVOR')),
          );
          expect(
            WindowsRunnerCMakeListsEditor.withFlavors(patched, {
              'apple': 'Apple App',
            }),
            patched,
          );
        });

        test('Runner.rc and main.cpp are templated, only where the flavor '
            'shows', () {
          final rc = _render(runner, 'Runner.rc.tmpl');
          final main = _render(runner, 'main.cpp.tmpl');
          final rcIn = WindowsRunnerRcTemplateEditor.template(rc);
          final mainIn = WindowsMainCppTemplateEditor.template(main);

          expect(rcIn, contains(r'"resources\\@RUNNER_APP_ICON@"'));
          expect('@WINDOW_TITLE@'.allMatches(rcIn), hasLength(2));
          expect(
            mainIn,
            contains('window.Create(L"@WINDOW_TITLE@", origin, size)'),
          );
          expect(
            rcIn
                .replaceAll('@RUNNER_APP_ICON@', 'app_icon.ico')
                .replaceAll('@WINDOW_TITLE@', 'my_app'),
            rc,
          );
          expect(mainIn.replaceAll('@WINDOW_TITLE@', 'my_app'), main);
        });

        test('Runner.rc has the UTF-8 code page that a title that is not '
            'ASCII needs', () {
          final rc = _render(runner, 'Runner.rc.tmpl');

          expect(rc, contains('#pragma code_page(65001)'));
          expect(
            WindowsRunnerRcTemplateEditor.template(rc, titles: ['Café 😀']),
            isNotEmpty,
          );
        });
      });
    }
  });
}
