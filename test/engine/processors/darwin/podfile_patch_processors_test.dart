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
import 'package:flutter_flavorizr/src/engine/flavorizr_processor.dart';
import 'package:flutter_flavorizr/src/engine/processors/darwin/podfile_patch_processor.dart';
import 'package:flutter_flavorizr/src/exception/unsafe_podfile_exception.dart';
import 'package:flutter_flavorizr/src/utils/constants.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../../test_utils.dart';

/// A processor of the group, the file it patches and the flavors it is for.
typedef _Case = ({
  String id,
  FlavorizrProcessor processor,
  String path,
  List<String> flavors,
  List<String> others,
});

final _cases = <_Case>[
  (
    id: 'ios:podfile',
    processor: const IosPodfilePatchProcessor(),
    path: K.iOSPodfilePath,
    flavors: ['apple', 'banana'],
    others: ['cherry'],
  ),
  (
    id: 'macos:podfile',
    processor: const MacosPodfilePatchProcessor(),
    path: K.macOSPodfilePath,
    flavors: ['apple', 'cherry'],
    others: ['banana'],
  ),
];

final String _pristine = File(
  'test_resources/darwin/podfile_test/PodfileOriginal',
).readAsStringSync();

/// apple is on both platforms, banana on iOS only and cherry on macOS only.
const _pubspec = '''
name: app
flavorizr:
  flavors:
    apple:
      app:
        name: "Apple"
      ios:
        bundleId: "com.example.apple"
      macos:
        bundleId: "com.example.apple"
    banana:
      app:
        name: "Banana"
      ios:
        bundleId: "com.example.banana"
    cherry:
      app:
        name: "Cherry"
      macos:
        bundleId: "com.example.cherry"
''';

void main() {
  late Directory root;
  late Directory projectRoot;
  late FlavorizrContext ctx;

  setUp(() {
    final temp = Directory.systemTemp.createTempSync('flavorizr_podfile_');
    addTearDown(() => temp.deleteSync(recursive: true));

    root = Directory(p.join(temp.path, 'shadow'))..createSync();
    projectRoot = Directory(p.join(temp.path, 'project'))..createSync();
    File(p.join(temp.path, 'pubspec.yaml')).writeAsStringSync(_pubspec);

    ctx = FlavorizrContext(
      config: TestUtils.parseFlavorizr(p.join(temp.path, 'pubspec')),
      root: root,
      projectRoot: projectRoot,
      logger: TestUtils.quietLogger(),
    );
  });

  File file(Directory base, String path) => File(p.join(base.path, path));

  for (final testCase in _cases) {
    group('${testCase.processor.runtimeType}', () {
      File podfile(Directory base) => file(base, testCase.path);

      void write(String content) => podfile(root)
        ..createSync(recursive: true)
        ..writeAsStringSync(content);

      test('is the `${testCase.id}` processor, which needs nothing and '
          'orders after nothing', () {
        expect(testCase.processor.id, testCase.id);
        expect(testCase.processor.dependsOn, isEmpty);
        expect(testCase.processor.after, isEmpty);
        expect(testCase.processor.requires, isEmpty);
      });

      test('maps the flavors of its platform only, and tracks the Podfile as '
          'patched', () async {
        write(_pristine);

        await testCase.processor.apply(ctx);

        final patched = podfile(root).readAsStringSync();

        for (final flavor in testCase.flavors) {
          expect(patched, contains("'Debug-$flavor' => :debug,"));
          expect(patched, contains("'Release-$flavor' => :release,"));
        }
        for (final flavor in testCase.others) {
          expect(patched, isNot(contains(flavor)));
        }
        expect(patched, contains("  'Debug' => :debug,"));
        expect(ctx.tracked, [Artifact.patched(testCase.path)]);
      });

      test('reads the shadow workspace, never the real project nor the '
          'working directory', () async {
        write(_pristine);
        podfile(projectRoot)
          ..createSync(recursive: true)
          ..writeAsStringSync('real');

        await testCase.processor.apply(ctx);

        expect(podfile(projectRoot).readAsStringSync(), 'real');
        expect(File(testCase.path).existsSync(), isFalse);
      });

      test('does not write a Podfile that is already up to date', () async {
        write(_pristine);
        await testCase.processor.apply(ctx);
        final modified = DateTime.utc(2020);
        podfile(root).setLastModifiedSync(modified);

        await testCase.processor.apply(ctx);

        expect(podfile(root).lastModifiedSync().toUtc(), modified);
      });

      test(
        'keeps the byte order mark and the line endings of the file',
        () async {
          podfile(root)
            ..createSync(recursive: true)
            ..writeAsBytesSync([
              0xef,
              0xbb,
              0xbf,
              ...utf8.encode(_pristine.replaceAll('\n', '\r\n')),
            ]);

          await testCase.processor.apply(ctx);

          final bytes = podfile(root).readAsBytesSync();
          final text = utf8.decode(bytes.sublist(3));

          expect(bytes.take(3), [0xef, 0xbb, 0xbf]);
          expect(text.replaceAll('\r\n', ''), isNot(contains('\n')));
          expect(text, contains('autogenerated by flutter_flavorizr'));
        },
      );

      test('skips a project that has no Podfile yet, as 2.x did: CocoaPods '
          'makes it, and nothing is written nor tracked', () async {
        await testCase.processor.apply(ctx);

        expect(podfile(root).existsSync(), isFalse);
        expect(ctx.tracked, isEmpty);
      });

      test(
        'fails on a Podfile it cannot edit, and leaves it as it is',
        () async {
          write("target 'Runner' do\nend\n");

          await expectLater(
            testCase.processor.apply(ctx),
            throwsA(
              isA<UnsafePodfileException>().having(
                (e) => e.path,
                'path',
                testCase.path,
              ),
            ),
          );

          expect(podfile(root).readAsStringSync(), "target 'Runner' do\nend\n");
          expect(ctx.tracked, isEmpty);
        },
      );
    });
  }

  test('the two processors patch their own file whatever the order they run '
      'in', () async {
    Future<Map<String, String>> run(List<FlavorizrProcessor> order) async {
      final temp = Directory.systemTemp.createTempSync('flavorizr_podfile_');
      addTearDown(() => temp.deleteSync(recursive: true));
      final shadow = Directory(p.join(temp.path, 'shadow'))..createSync();

      for (final testCase in _cases) {
        file(shadow, testCase.path)
          ..createSync(recursive: true)
          ..writeAsStringSync(_pristine);
      }

      final context = FlavorizrContext(
        config: ctx.config,
        root: shadow,
        projectRoot: projectRoot,
        logger: TestUtils.quietLogger(),
      );

      for (final processor in order) {
        await processor.apply(context);
      }

      return {
        for (final testCase in _cases)
          testCase.path: file(shadow, testCase.path).readAsStringSync(),
      };
    }

    final processors = [for (final testCase in _cases) testCase.processor];

    final forward = await run(processors);
    final backward = await run(processors.reversed.toList());

    expect(backward, forward);
    expect(forward[K.iOSPodfilePath], isNot(forward[K.macOSPodfilePath]));
  });
}
