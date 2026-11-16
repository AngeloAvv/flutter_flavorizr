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
import 'package:flutter_flavorizr/src/engine/processors/android/android_manifest_patch_processor.dart';
import 'package:flutter_flavorizr/src/exception/file_not_found_exception.dart';
import 'package:flutter_flavorizr/src/exception/malformed_resource_exception.dart';
import 'package:flutter_flavorizr/src/utils/constants.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../../test_utils.dart';

void main() {
  late Directory root;
  late Directory projectRoot;
  late FlavorizrContext ctx;

  File manifest(Directory base) =>
      File(p.join(base.path, 'android/app/src/main/AndroidManifest.xml'));

  setUp(() {
    final temp = Directory.systemTemp.createTempSync('flavorizr_manifest_');
    addTearDown(() => temp.deleteSync(recursive: true));

    root = Directory(p.join(temp.path, 'shadow'))..createSync();
    projectRoot = Directory(p.join(temp.path, 'project'))..createSync();

    ctx = FlavorizrContext(
      config: TestUtils.parseFlavorizr('test_resources/pubspec'),
      root: root,
      projectRoot: projectRoot,
      logger: TestUtils.quietLogger(),
    );
  });

  group('AndroidManifestPatchProcessor', () {
    test('is the `android:androidManifest` processor, with no edges', () {
      final processor = AndroidManifestPatchProcessor();

      expect(processor.id, 'android:androidManifest');
      expect(processor.dependsOn, isEmpty);
      expect(processor.after, isEmpty);
      expect(processor.requires, isEmpty);
    });

    test('points the label to the app name and tracks the manifest as '
        'patched', () async {
      manifest(root)
        ..createSync(recursive: true)
        ..writeAsStringSync(
          '<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n'
          '  <application android:label="example"/>\n'
          '</manifest>\n',
        );

      await AndroidManifestPatchProcessor().apply(ctx);

      expect(
        manifest(root).readAsStringSync(),
        '<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '  <application android:label="@string/app_name"/>\n'
        '</manifest>\n',
      );
      expect(ctx.tracked, [Artifact.patched(K.androidManifestPath)]);
    });

    test('reads the shadow workspace, never the real project nor the working '
        'directory', () async {
      manifest(root)
        ..createSync(recursive: true)
        ..writeAsStringSync(
          '<manifest xmlns:android="x"><application android:label="a"/></manifest>',
        );
      manifest(projectRoot)
        ..createSync(recursive: true)
        ..writeAsStringSync(
          '<manifest xmlns:android="x"><application android:label="real"/></manifest>',
        );

      await AndroidManifestPatchProcessor().apply(ctx);

      expect(manifest(projectRoot).readAsStringSync(), contains('"real"'));
      expect(File(K.androidManifestPath).existsSync(), isFalse);
    });

    test('does not write a manifest that is already up to date', () async {
      final file = manifest(root)..createSync(recursive: true);
      file.writeAsStringSync(
        '<manifest xmlns:android="x">\n'
        '<application android:label="@string/app_name"/></manifest>',
      );
      final modified = DateTime.utc(2020);
      file.setLastModifiedSync(modified);

      await AndroidManifestPatchProcessor().apply(ctx);

      expect(file.lastModifiedSync().toUtc(), modified);
      expect(ctx.tracked, [Artifact.patched(K.androidManifestPath)]);
    });

    test(
      'keeps the byte order mark and the line endings of the file',
      () async {
        final bytes = [
          0xef,
          0xbb,
          0xbf,
          ...utf8.encode(
            '<manifest xmlns:android="x">\r\n'
            '<application android:label="é"/>\r\n</manifest>',
          ),
        ];
        manifest(root)
          ..createSync(recursive: true)
          ..writeAsBytesSync(bytes);

        await AndroidManifestPatchProcessor().apply(ctx);

        expect(manifest(root).readAsBytesSync(), [
          0xef,
          0xbb,
          0xbf,
          ...utf8.encode(
            '<manifest xmlns:android="x">\r\n'
            '<application android:label="@string/app_name"/>\r\n</manifest>',
          ),
        ]);
      },
    );

    test('fails when there is no manifest', () {
      expect(
        AndroidManifestPatchProcessor().apply(ctx),
        throwsA(isA<FileNotFoundException>()),
      );
    });

    test('fails on a manifest it cannot edit', () {
      manifest(root)
        ..createSync(recursive: true)
        ..writeAsStringSync('<manifest xmlns:android="x"/>');

      expect(
        AndroidManifestPatchProcessor().apply(ctx),
        throwsA(isA<MalformedResourceException>()),
      );
    });
  });
}
