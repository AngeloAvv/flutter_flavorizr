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
import 'package:flutter_flavorizr/src/engine/processors/darwin/info_plist_patch_processor.dart';
import 'package:flutter_flavorizr/src/exception/file_not_found_exception.dart';
import 'package:flutter_flavorizr/src/exception/malformed_resource_exception.dart';
import 'package:flutter_flavorizr/src/utils/constants.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../../test_utils.dart';

final String _ios = File(
  'test_resources/darwin/info_plist_test/IosInfoPlistOriginal.plist',
).readAsStringSync();
final String _macos = File(
  'test_resources/darwin/info_plist_test/MacosInfoPlistOriginal.plist',
).readAsStringSync();

String _pubspec({List<String> instructions = const []}) =>
    '''
name: app
flavorizr:
${instructions.isEmpty ? '' : '  instructions:\n${instructions.map((i) => '    - $i\n').join()}'}  flavors:
    apple:
      app:
        name: "Apple"
      ios:
        bundleId: "com.example.apple"
      macos:
        bundleId: "com.example.apple"
''';

void main() {
  late Directory temp;
  late Directory root;
  late Directory projectRoot;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('flavorizr_plist_');
    addTearDown(() => temp.deleteSync(recursive: true));

    root = Directory(p.join(temp.path, 'shadow'))..createSync();
    projectRoot = Directory(p.join(temp.path, 'project'))..createSync();
  });

  FlavorizrContext context({List<String> instructions = const []}) {
    File(
      p.join(temp.path, 'pubspec.yaml'),
    ).writeAsStringSync(_pubspec(instructions: instructions));

    return FlavorizrContext(
      config: TestUtils.parseFlavorizr(p.join(temp.path, 'pubspec')),
      root: root,
      projectRoot: projectRoot,
      logger: TestUtils.quietLogger(),
    );
  }

  File plist(String path) => File(p.join(root.path, path));

  void write(String path, String content) => plist(path)
    ..createSync(recursive: true)
    ..writeAsStringSync(content);

  group('IosInfoPlistPatchProcessor', () {
    const processor = IosInfoPlistPatchProcessor();

    test('is the `ios:plist` processor, which needs nothing and orders after '
        'nothing', () {
      expect(processor.id, 'ios:plist');
      expect(processor.dependsOn, isEmpty);
      expect(processor.after, isEmpty);
      expect(processor.requires, isEmpty);
    });

    test('sets the name and the display name, leaves the launch screen alone '
        'and tracks the plist as patched', () async {
      write(K.iOSPListPath, _ios);
      final ctx = context();

      await processor.apply(ctx);

      expect(
        plist(K.iOSPListPath).readAsStringSync(),
        _ios
            .replaceFirst(
              '<string>Example</string>',
              r'<string>$(BUNDLE_DISPLAY_NAME)</string>',
            )
            .replaceFirst(
              '<string>example</string>',
              r'<string>$(BUNDLE_NAME)</string>',
            ),
      );
      expect(ctx.tracked, [Artifact.patched(K.iOSPListPath)]);
    });

    test('sets the launch storyboard when the launch screen is an '
        'instruction', () async {
      write(K.iOSPListPath, _ios);

      await processor.apply(context(instructions: ['ios:launchScreen']));

      expect(
        plist(K.iOSPListPath).readAsStringSync(),
        contains(r'<string>$(ASSET_PREFIX)LaunchScreen</string>'),
      );
    });

    test('does not write a plist that is already up to date', () async {
      write(K.iOSPListPath, _ios);
      await processor.apply(context());
      final modified = DateTime.utc(2020);
      plist(K.iOSPListPath).setLastModifiedSync(modified);

      await processor.apply(context());

      expect(plist(K.iOSPListPath).lastModifiedSync().toUtc(), modified);
    });

    test('reads the shadow workspace, never the real project', () async {
      write(K.iOSPListPath, _ios);
      File(p.join(projectRoot.path, K.iOSPListPath))
        ..createSync(recursive: true)
        ..writeAsStringSync('real');

      final working = File(K.iOSPListPath);
      final workingBefore = working.existsSync()
          ? working.readAsBytesSync()
          : null;

      await processor.apply(context());

      expect(
        File(p.join(projectRoot.path, K.iOSPListPath)).readAsStringSync(),
        'real',
      );
      expect(
        working.existsSync() ? working.readAsBytesSync() : null,
        workingBefore,
      );
    });

    test(
      'keeps the byte order mark and the line endings of the file',
      () async {
        plist(K.iOSPListPath)
          ..createSync(recursive: true)
          ..writeAsBytesSync([
            0xef,
            0xbb,
            0xbf,
            ...utf8.encode(_ios.replaceAll('\n', '\r\n')),
          ]);

        await processor.apply(context());

        expect(plist(K.iOSPListPath).readAsBytesSync(), [
          0xef,
          0xbb,
          0xbf,
          ...utf8.encode(
            _ios
                .replaceFirst(
                  '<string>Example</string>',
                  r'<string>$(BUNDLE_DISPLAY_NAME)</string>',
                )
                .replaceFirst(
                  '<string>example</string>',
                  r'<string>$(BUNDLE_NAME)</string>',
                )
                .replaceAll('\n', '\r\n'),
          ),
        ]);
      },
    );

    test('fails when the plist is not there, and tracks nothing', () async {
      final ctx = context();

      await expectLater(
        processor.apply(ctx),
        throwsA(isA<FileNotFoundException>()),
      );
      expect(ctx.tracked, isEmpty);
    });

    test('fails on a plist without the keys, and leaves it as it is', () async {
      const source =
          '<plist version="1.0"><dict><key>A</key><string>b</string></dict></plist>';
      write(K.iOSPListPath, source);
      final ctx = context();

      await expectLater(
        processor.apply(ctx),
        throwsA(isA<MalformedResourceException>()),
      );
      expect(plist(K.iOSPListPath).readAsStringSync(), source);
      expect(ctx.tracked, isEmpty);
    });
  });

  group('MacosInfoPlistPatchProcessor', () {
    const processor = MacosInfoPlistPatchProcessor();

    test('is the `macos:plist` processor', () {
      expect(processor.id, 'macos:plist');
      expect(processor.dependsOn, isEmpty);
      expect(processor.requires, isEmpty);
    });

    test('sets the name and nothing else, whatever the instructions', () async {
      write(K.macOSPlistPath, _macos);
      final ctx = context(instructions: ['ios:launchScreen']);

      await processor.apply(ctx);

      expect(
        plist(K.macOSPlistPath).readAsStringSync(),
        _macos.replaceFirst(r'$(PRODUCT_NAME)', r'$(BUNDLE_NAME)'),
      );
      expect(ctx.tracked, [Artifact.patched(K.macOSPlistPath)]);
    });
  });
}
