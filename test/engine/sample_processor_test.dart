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

import 'package:flutter_flavorizr/src/engine/artifact.dart';
import 'package:flutter_flavorizr/src/engine/flavorizr_context.dart';
import 'package:flutter_flavorizr/src/engine/flavorizr_processor.dart';
import 'package:flutter_flavorizr/src/processors/flutter/flutter_flavors_processor.dart';
import 'package:flutter_flavorizr/src/utils/constants.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../test_utils.dart';

/// A sample of how a processor is written against the new contract.
///
/// It produces `lib/flavors.dart` in the shadow workspace and mirrors a user
/// supplied icon from the real project. Every path goes through the context:
/// the relative paths of [K] are never opened directly.
class _SampleFlavorsProcessor extends FlavorizrProcessor {
  static const iconSource = 'assets/icon.png';
  static const iconTarget = 'assets/flavors/icon.png';

  @override
  String get id => 'sample:flavors';

  @override
  Future<void> apply(FlavorizrContext ctx) async {
    final content = FlutterFlavorsProcessor(
      config: ctx.config,
      logger: ctx.logger,
    ).execute();

    final flavors = File(ctx.resolve(K.flutterFlavorPath));
    await flavors.create(recursive: true);
    await flavors.writeAsString(content);
    ctx.track(const Artifact.managed('lib/flavors.dart'));

    final icon = File(ctx.resolveProject(iconSource));
    if (icon.existsSync()) {
      final target = File(ctx.resolve(iconTarget));
      await target.create(recursive: true);
      await icon.copy(target.path);
      ctx.track(const Artifact.managed(iconTarget));
    }
  }
}

void main() {
  late Directory root;
  late Directory projectRoot;
  late FlavorizrContext ctx;

  setUp(() {
    final temp = Directory.systemTemp.createTempSync('flavorizr_sample_');
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

  group('A processor written against the contract', () {
    test('writes its output below the shadow root and tracks it', () async {
      await _SampleFlavorsProcessor().apply(ctx);

      final flavors = File(p.join(root.path, 'lib', 'flavors.dart'));
      expect(flavors.existsSync(), isTrue);
      expect(flavors.readAsStringSync(), contains('enum Flavor {'));
      expect(ctx.tracked.map((artifact) => artifact.path), [
        'lib/flavors.dart',
      ]);
    });

    test(
      'reads user inputs from the project and writes them to the root',
      () async {
        File(p.join(projectRoot.path, _SampleFlavorsProcessor.iconSource))
          ..createSync(recursive: true)
          ..writeAsBytesSync([1, 2, 3]);

        await _SampleFlavorsProcessor().apply(ctx);

        expect(
          File(
            p.join(root.path, 'assets', 'flavors', 'icon.png'),
          ).readAsBytesSync(),
          [1, 2, 3],
        );
        expect(ctx.tracked.map((artifact) => artifact.path), [
          'lib/flavors.dart',
          'assets/flavors/icon.png',
        ]);
      },
    );

    test(
      'leaves the real project and the working directory untouched',
      () async {
        File(p.join(projectRoot.path, _SampleFlavorsProcessor.iconSource))
          ..createSync(recursive: true)
          ..writeAsBytesSync([1, 2, 3]);

        await _SampleFlavorsProcessor().apply(ctx);

        expect(
          projectRoot
              .listSync(recursive: true)
              .whereType<File>()
              .map((file) => p.relative(file.path, from: projectRoot.path)),
          [p.join('assets', 'icon.png')],
        );
        // The repository has no `lib/flavors.dart`: a processor that resolved
        // `K.flutterFlavorPath` against the working directory would create it.
        expect(File(K.flutterFlavorPath).existsSync(), isFalse);
      },
    );
  });
}
