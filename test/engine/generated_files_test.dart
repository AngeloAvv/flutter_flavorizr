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

import 'package:flutter_flavorizr/src/engine/flavorizr_context.dart';
import 'package:flutter_flavorizr/src/engine/recorded_output.dart';
import 'package:flutter_flavorizr/src/engine/shadow/file_digest.dart';
import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

const icon = 'android/app/src/dev/res/mipmap-mdpi/ic_launcher.png';

void main() {
  group('FlavorizrContext.isGeneratedFrom', () {
    late Directory temp;
    late Directory shadow;

    FlavorizrContext build({
      String? processorId = 'android:icons',
      Map<String, Map<String, RecordedOutput>> previousOutputs = const {},
    }) => FlavorizrContext(
      config: FlavorizrConfig.parse('''
flavors:
  dev:
    app:
      name: Dev
    android:
      applicationId: com.example.dev
'''),
      root: shadow,
      projectRoot: Directory(p.join(temp.path, 'project'))..createSync(),
      logger: Logger(level: Level.quiet),
      processorId: processorId,
      previousOutputs: previousOutputs,
    );

    Map<String, Map<String, RecordedOutput>> recorded(
      String content, {
      String inputs = 'i1',
      String path = icon,
      String id = 'android:icons',
    }) => {
      id: {
        path: RecordedOutput(
          hash: digestOf(utf8.encode(content)),
          inputs: inputs,
        ),
      },
    };

    void write(String content, {String path = icon}) {
      final file = File(p.join(shadow.path, path));

      file.parent.createSync(recursive: true);
      file.writeAsStringSync(content);
    }

    setUp(() {
      temp = Directory.systemTemp.createTempSync('flavorizr_generated_');
      shadow = Directory(p.join(temp.path, 'shadow'))..createSync();
      addTearDown(() => temp.deleteSync(recursive: true));
    });

    test('is true for the inputs and the content the lock recorded', () async {
      write('png');

      final ctx = build(previousOutputs: recorded('png'));

      expect(await ctx.isGeneratedFrom(icon, 'i1'), isTrue);
    });

    test('is false when the inputs changed', () async {
      write('png');

      final ctx = build(previousOutputs: recorded('png'));

      expect(await ctx.isGeneratedFrom(icon, 'i2'), isFalse);
    });

    test(
      'is false when the file was edited, so that it is found out',
      () async {
        write('edited by hand');

        final ctx = build(previousOutputs: recorded('png'));

        expect(await ctx.isGeneratedFrom(icon, 'i1'), isFalse);
      },
    );

    test('is false when the file is gone', () async {
      final ctx = build(previousOutputs: recorded('png'));

      expect(await ctx.isGeneratedFrom(icon, 'i1'), isFalse);
    });

    test('is false on the first run and for a file the lock has no inputs '
        'for', () async {
      write('png');

      expect(await build().isGeneratedFrom(icon, 'i1'), isFalse);
      expect(
        await build(
          previousOutputs: recorded('png', path: 'android/other.png'),
        ).isGeneratedFrom(icon, 'i1'),
        isFalse,
      );
    });

    test('is false for what another processor recorded', () async {
      write('png');

      final ctx = build(previousOutputs: recorded('png', id: 'ios:icons'));

      expect(await ctx.isGeneratedFrom(icon, 'i1'), isFalse);
    });

    test('is false for a link, which is never followed', () async {
      final target = File(p.join(temp.path, 'target.png'))
        ..writeAsStringSync('png');
      final link = Link(p.join(shadow.path, icon))
        ..createSync(target.path, recursive: true);

      expect(link.existsSync(), isTrue);

      final ctx = build(previousOutputs: recorded('png'));

      expect(await ctx.isGeneratedFrom(icon, 'i1'), isFalse);
    });

    test('reads the paths of the lock in their canonical form', () async {
      write('png');

      final ctx = build(
        previousOutputs: recorded(
          'png',
          path: r'android\app\src\dev\res\mipmap-mdpi\ic_launcher.png',
        ),
      );

      expect(await ctx.isGeneratedFrom(icon, 'i1'), isTrue);
    });

    test('a path that leaves the project is refused', () {
      final ctx = build();

      expect(
        () => ctx.isGeneratedFrom('../escape.png', 'i1'),
        throwsArgumentError,
      );
    });

    test('is false on a context that is not for a processor', () async {
      write('png');

      final ctx = build(processorId: null, previousOutputs: recorded('png'));

      expect(await ctx.isGeneratedFrom(icon, 'i1'), isFalse);
    });
  });
}
