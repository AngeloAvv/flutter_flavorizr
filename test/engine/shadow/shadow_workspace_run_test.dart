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
import 'package:flutter_flavorizr/src/engine/shadow/shadow_workspace.dart';
import 'package:flutter_flavorizr/src/exception/project_changed_exception.dart';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;

import '../../test_utils.dart';
import 'shadow_fixture.dart';

/// Writes a file and a second one in the shadow workspace, and fails between
/// them, like a processor hitting a malformed project would.
class _CrashingProcessor extends FlavorizrProcessor {
  @override
  String get id => 'test:crashing';

  @override
  Future<void> apply(FlavorizrContext ctx) async {
    File(ctx.resolve('lib/flavors.dart')).writeAsStringSync('generated');
    ctx.track(const Artifact.managed('lib/flavors.dart'));

    throw StateError('malformed project');
  }
}

class _WritingProcessor extends FlavorizrProcessor {
  @override
  String get id => 'test:writing';

  @override
  Future<void> apply(FlavorizrContext ctx) async {
    File(ctx.resolve('lib/flavors.dart')).writeAsStringSync('generated');
    ctx.track(const Artifact.local('lib/flavors.dart'));
  }
}

void main() {
  late ShadowFixture fx;

  setUp(() => fx = ShadowFixture());
  tearDown(() => fx.dispose());

  FlavorizrContext contextFor(ShadowWorkspace shadow) => FlavorizrContext(
    config: TestUtils.parseFlavorizr('test_resources/pubspec'),
    root: shadow.root,
    projectRoot: shadow.projectRoot,
    logger: TestUtils.quietLogger(),
  );

  Future<T> run<T>(Future<T> Function(ShadowWorkspace shadow) body) =>
      ShadowWorkspace.run(
        projectRoot: fx.project.root,
        paths: ['lib'],
        body: body,
      );

  group('ShadowWorkspace.run', () {
    test('returns what the body returns and deletes the shadow', () async {
      late Directory root;

      final result = await run((shadow) async {
        root = shadow.root;
        expect(root.existsSync(), isTrue);

        return 42;
      });

      expect(result, 42);
      expect(root.existsSync(), isFalse);
    });

    test('a failing processor leaves the real project untouched', () async {
      fx.project.write('lib/flavors.dart', 'hand written');
      fx.project.write('lib/main.dart', 'main');
      late Directory root;

      await expectLater(
        run((shadow) async {
          root = shadow.root;
          await _CrashingProcessor().apply(contextFor(shadow));
          await shadow.copyBack(await shadow.diff());
        }),
        throwsStateError,
      );

      expect(fx.project.read('lib/flavors.dart'), 'hand written');
      expect(fx.project.read('lib/main.dart'), 'main');
      expect(root.existsSync(), isFalse);
    });

    test('plan: the diff is computed and nothing is written', () async {
      fx.project.write('lib/flavors.dart', 'old');
      late String printed;
      late Directory root;

      await run((shadow) async {
        root = shadow.root;
        final context = contextFor(shadow);
        await _WritingProcessor().apply(context);

        printed = (await shadow.diff(tracked: context.tracked)).render();
      });

      expect(printed, '~ lib/flavors.dart (local)');
      expect(fx.project.read('lib/flavors.dart'), 'old');
      expect(root.existsSync(), isFalse);
    });

    test('apply: processors write below ctx.root, then copy back', () async {
      fx.project.write('lib/flavors.dart', 'old');

      await run((shadow) async {
        final context = contextFor(shadow);
        await _WritingProcessor().apply(context);

        expect(fx.project.read('lib/flavors.dart'), 'old');

        final diff = await shadow.diff(tracked: context.tracked);
        await shadow.copyBack(diff);
      });

      expect(fx.project.read('lib/flavors.dart'), 'generated');
    });

    test('deletes the shadow when copy-back is refused', () async {
      fx.project.write('lib/flavors.dart', 'old');
      late Directory root;

      await expectLater(
        run((shadow) async {
          root = shadow.root;
          final context = contextFor(shadow);
          await _WritingProcessor().apply(context);
          final diff = await shadow.diff(tracked: context.tracked);

          fx.project.write('lib/flavors.dart', 'edited meanwhile');
          await shadow.copyBack(diff);
        }),
        throwsA(isA<ProjectChangedException>()),
      );

      expect(root.existsSync(), isFalse);
      expect(fx.project.read('lib/flavors.dart'), 'edited meanwhile');
    });

    test('deletes the shadow when the whitelist is invalid', () async {
      final parent = Directory(p.join(fx.scratch.path, 'tmp'))..createSync();

      await expectLater(
        ShadowWorkspace.run(
          projectRoot: fx.project.root,
          paths: ['../outside'],
          tempParent: parent,
          body: (shadow) async {},
        ),
        throwsArgumentError,
      );

      expect(parent.listSync(), isEmpty);
    });
  });
}
