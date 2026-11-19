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

import 'dart:convert';
import 'dart:io';

import 'package:flutter_flavorizr/src/engine/artifact.dart';
import 'package:flutter_flavorizr/src/engine/flavorizr_context.dart';
import 'package:flutter_flavorizr/src/engine/processors/windows/windows_main_cpp_template_processor.dart';
import 'package:flutter_flavorizr/src/engine/processors/windows/windows_runner_cmake_lists_patch_processor.dart';
import 'package:flutter_flavorizr/src/engine/processors/windows/windows_runner_rc_template_processor.dart';
import 'package:flutter_flavorizr/src/engine/processors/windows/windows_template_processor.dart';
import 'package:flutter_flavorizr/src/exception/file_not_found_exception.dart';
import 'package:flutter_flavorizr/src/exception/unsupported_runner_layout_exception.dart';
import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:flutter_flavorizr/src/utils/constants.dart';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;

import '../../../test_utils.dart';

String _resource(String path) =>
    File('test_resources/windows/$path').readAsStringSync();

/// [text] as UTF-16 with a byte order mark.
List<int> _utf16(String text, {required bool bigEndian}) => [
  if (bigEndian) ...[0xfe, 0xff] else ...[0xff, 0xfe],
  for (final unit in text.codeUnits)
    ...(bigEndian ? [unit >> 8, unit & 0xff] : [unit & 0xff, unit >> 8]),
];

void main() {
  late Directory root;
  late Directory projectRoot;
  late FlavorizrContext ctx;

  setUp(() {
    final temp = Directory.systemTemp.createTempSync('flavorizr_windows_');
    addTearDown(() => temp.deleteSync(recursive: true));

    root = Directory(p.join(temp.path, 'shadow'))..createSync();
    projectRoot = Directory(p.join(temp.path, 'project'))..createSync();

    ctx = FlavorizrContext(
      config: TestUtils.parseFlavorizr('test_resources/windows/pubspec'),
      root: root,
      projectRoot: projectRoot,
      logger: TestUtils.quietLogger(),
    );
  });

  File file(Directory base, String path) => File(p.join(base.path, path));

  void write(Directory base, String path, List<int> bytes) => file(base, path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes);

  group('the processors that make a template', () {
    final cases =
        <
          ({
            WindowsTemplateProcessor processor,
            String id,
            Set<String> after,
            String source,
            String target,
            String pristine,
            String template,
          })
        >[
          (
            processor: const WindowsMainCppTemplateProcessor(),
            id: 'windows:mainCppTemplate',
            after: {},
            source: K.windowsMainCppPath,
            target: K.windowsMainCppTemplatePath,
            pristine: _resource('main_cpp_title_processor_test/main.cpp'),
            template: _resource(
              'main_cpp_title_processor_test/main_expected.cpp',
            ),
          ),
          (
            processor: const WindowsRunnerRcTemplateProcessor(),
            id: 'windows:runnerRcTemplate',
            after: {'windows:mainCppTemplate'},
            source: K.windowsRunnerRcPath,
            target: K.windowsRunnerRcTemplatePath,
            pristine: _resource('runner_rc_content_processor_test/Runner.rc'),
            template: _resource(
              'runner_rc_content_processor_test/Runner_expected.rc',
            ),
          ),
        ];

    for (final testCase in cases) {
      group('${testCase.processor.runtimeType}', () {
        final processor = testCase.processor;

        test('is the `${testCase.id}` processor, which orders after the one '
            'before it but needs none', () {
          expect(processor.id, testCase.id);
          expect(processor.dependsOn, isEmpty);
          expect(processor.after, testCase.after);
          expect(processor.requires, isEmpty);
          expect(processor.sourcePath, testCase.source);
          expect(processor.targetPath, testCase.target);
        });

        test('writes the template, as a managed artifact, from the file of '
            'the project, which it leaves as it is', () async {
          write(projectRoot, testCase.source, utf8.encode(testCase.pristine));

          await processor.apply(ctx);

          expect(
            file(root, testCase.target).readAsStringSync(),
            testCase.template,
          );
          expect(file(root, testCase.source).existsSync(), isFalse);
          expect(
            file(projectRoot, testCase.source).readAsStringSync(),
            testCase.pristine,
          );
          expect(ctx.tracked, [Artifact.managed(testCase.target)]);
        });

        test('makes the same template from a file a 2.x build already '
            'changed', () async {
          write(
            projectRoot,
            testCase.source,
            utf8.encode(
              testCase.pristine
                  .replaceAll(
                    r'resources\\app_icon.ico',
                    r'resources\\apple.ico',
                  )
                  .replaceAll('L"example"', 'L"Apple App"')
                  .replaceAllMapped(
                    RegExp(r'(FileDescription|ProductName)", "example"'),
                    (match) => '${match[1]}", "Apple App"',
                  ),
            ),
          );

          await processor.apply(ctx);

          expect(
            file(root, testCase.target).readAsStringSync(),
            testCase.template,
          );
        });

        test(
          'keeps the byte order mark and the line endings of the file',
          () async {
            write(projectRoot, testCase.source, [
              0xef,
              0xbb,
              0xbf,
              ...utf8.encode(testCase.pristine.replaceAll('\n', '\r\n')),
            ]);

            await processor.apply(ctx);

            final bytes = file(root, testCase.target).readAsBytesSync();

            expect(bytes.take(3), [0xef, 0xbb, 0xbf]);
            expect(
              utf8.decode(bytes.sublist(3)),
              testCase.template.replaceAll('\n', '\r\n'),
            );
          },
        );

        test('fails when there is no file', () {
          expect(processor.apply(ctx), throwsA(isA<FileNotFoundException>()));
        });

        test('rejects a control character that is not a space or a line break: '
            'NUL, form feed, vertical tab, a lone carriage return', () async {
          for (final bad in ['\u0000', '\f', '\v', '\r']) {
            write(
              projectRoot,
              testCase.source,
              utf8.encode('${testCase.pristine}a${bad}b\n'),
            );

            await expectLater(
              processor.apply(ctx),
              throwsA(
                isA<UnsupportedRunnerLayoutException>().having(
                  (e) => e.toString(),
                  'message',
                  contains('control character'),
                ),
              ),
              reason: bad.codeUnits.toString(),
            );
            expect(file(root, testCase.target).existsSync(), isFalse);
          }
        });

        test('rejects a file that is not UTF-8, which is what the resource '
            'editor of Visual Studio may save, and writes nothing', () async {
          for (final bytes in [
            _utf16(testCase.pristine, bigEndian: false),
            _utf16(testCase.pristine, bigEndian: true),
            [0x61, 0xff, 0xfe, 0x62],
          ]) {
            write(projectRoot, testCase.source, bytes);

            await expectLater(
              processor.apply(ctx),
              throwsA(
                isA<UnsupportedRunnerLayoutException>().having(
                  (e) => e.toString(),
                  'message',
                  contains('UTF-8'),
                ),
              ),
            );
            expect(file(root, testCase.target).existsSync(), isFalse);
          }
        });

        test(
          'fails on a file it cannot template, and writes nothing',
          () async {
            write(projectRoot, testCase.source, utf8.encode('nothing\n'));

            await expectLater(
              processor.apply(ctx),
              throwsA(isA<UnsupportedRunnerLayoutException>()),
            );
            expect(file(root, testCase.target).existsSync(), isFalse);
            expect(ctx.tracked, isEmpty);
          },
        );
      });
    }
  });

  group('WindowsRunnerRcTemplateProcessor and a title that is not ASCII', () {
    const processor = WindowsRunnerRcTemplateProcessor();
    final pristine = _resource('runner_rc_content_processor_test/Runner.rc');
    FlavorizrContext contextOf(String title) => FlavorizrContext(
      config: FlavorizrConfig.parse(
        'flavors:\n  apple:\n    app:\n      name: "$title"\n    windows: {}\n',
      ),
      root: root,
      projectRoot: projectRoot,
      logger: TestUtils.quietLogger(),
    );

    test('is written when Runner.rc has the UTF-8 code page', () async {
      write(projectRoot, K.windowsRunnerRcPath, utf8.encode(pristine));

      await processor.apply(contextOf('Café'));

      expect(file(root, K.windowsRunnerRcTemplatePath).existsSync(), isTrue);
    });

    test('is rejected when it has none, and nothing is written', () async {
      write(
        projectRoot,
        K.windowsRunnerRcPath,
        utf8.encode(pristine.replaceFirst('#pragma code_page(65001)', '')),
      );

      await expectLater(
        processor.apply(contextOf('Café')),
        throwsA(
          isA<UnsupportedRunnerLayoutException>().having(
            (e) => e.toString(),
            'message',
            contains('code_page(65001)'),
          ),
        ),
      );
      expect(file(root, K.windowsRunnerRcTemplatePath).existsSync(), isFalse);
    });
  });

  group('WindowsRunnerCMakeListsPatchProcessor', () {
    const processor = WindowsRunnerCMakeListsPatchProcessor();
    final pristine = _resource(
      'runner_cmake_lists_processor_test/CMakeLists.txt',
    );
    final path = K.windowsRunnerCMakeListsPath;

    test('is the `windows:cmake` processor, which orders after the '
        'templates but needs none', () {
      expect(processor.id, 'windows:cmake');
      expect(processor.dependsOn, isEmpty);
      expect(processor.after, {'windows:runnerRcTemplate'});
      expect(processor.requires, isEmpty);
    });

    test('patches the file of the workspace for every flavor, and tracks it '
        'as patched', () async {
      write(root, path, utf8.encode(pristine));

      await processor.apply(ctx);

      final patched = file(root, path).readAsStringSync();

      expect(patched, contains('FLUTTER_APP_FLAVOR STREQUAL "apple"'));
      expect(patched, contains('set(WINDOW_TITLE_CPP "Banana App")'));
      expect(patched, contains('set(WINDOW_TITLE_RC "Banana App")'));
      expect(patched, contains(r'"${CMAKE_CURRENT_BINARY_DIR}/Runner.rc"'));
      expect(ctx.tracked, [Artifact.patched(path)]);
    });

    test('gives a flavor with a badge the icon that is made for it', () async {
      write(root, path, utf8.encode(pristine));
      final badged = FlavorizrContext(
        config: FlavorizrConfig.parse('''
flavors:
  banana:
    app:
      name: "Banana App"
    badge: true
    windows: {}
'''),
        root: root,
        projectRoot: projectRoot,
        logger: TestUtils.quietLogger(),
      );

      await processor.apply(ctx);
      expect(file(root, path).readAsStringSync(), isNot(contains('banana.ico')));

      await processor.apply(badged);

      expect(file(root, path).readAsStringSync(), contains('banana.ico'));
    });

    test('reads the shadow workspace, never the real project nor the '
        'working directory', () async {
      write(root, path, utf8.encode(pristine));
      write(projectRoot, path, utf8.encode('real'));

      await processor.apply(ctx);

      expect(file(projectRoot, path).readAsStringSync(), 'real');
      expect(File(path).existsSync(), isFalse);
    });

    test('does not write a file that is already up to date', () async {
      write(root, path, utf8.encode(pristine));
      await processor.apply(ctx);
      final modified = DateTime.utc(2020);
      file(root, path).setLastModifiedSync(modified);

      await processor.apply(ctx);

      expect(file(root, path).lastModifiedSync().toUtc(), modified);
    });

    test(
      'keeps the byte order mark and the line endings of the file',
      () async {
        write(root, path, [
          0xef,
          0xbb,
          0xbf,
          ...utf8.encode(pristine.replaceAll('\n', '\r\n')),
        ]);

        await processor.apply(ctx);

        final bytes = file(root, path).readAsBytesSync();
        final text = utf8.decode(bytes.sublist(3));

        expect(bytes.take(3), [0xef, 0xbb, 0xbf]);
        expect(text.replaceAll('\r\n', ''), isNot(contains('\n')));
        expect(text, contains('autogenerated by flutter_flavorizr'));
      },
    );

    test('fails when there is no file', () {
      expect(processor.apply(ctx), throwsA(isA<FileNotFoundException>()));
    });

    test('rejects a control character that is not a space or a line break, '
        'and leaves the file as it is', () async {
      final bytes = utf8.encode('$pristine\u0000\n');

      write(root, path, bytes);

      await expectLater(
        processor.apply(ctx),
        throwsA(
          isA<UnsupportedRunnerLayoutException>().having(
            (e) => e.toString(),
            'message',
            contains('control character'),
          ),
        ),
      );
      expect(file(root, path).readAsBytesSync(), bytes);
    });

    test('rejects a file that is not UTF-8, and leaves it as it is', () async {
      final utf16 = _utf16(pristine, bigEndian: false);

      write(root, path, utf16);

      await expectLater(
        processor.apply(ctx),
        throwsA(
          isA<UnsupportedRunnerLayoutException>().having(
            (e) => e.toString(),
            'message',
            contains('UTF-8'),
          ),
        ),
      );
      expect(file(root, path).readAsBytesSync(), utf16);
    });

    test('fails on a file it cannot edit', () {
      write(root, path, utf8.encode('nothing to anchor to\n'));

      expect(
        processor.apply(ctx),
        throwsA(isA<UnsupportedRunnerLayoutException>()),
      );
    });
  });
}
