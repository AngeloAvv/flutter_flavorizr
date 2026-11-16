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
import 'package:flutter_flavorizr/src/engine/resource_key.dart';
import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../test_utils.dart';

void main() {
  late Directory root;
  late Directory projectRoot;
  late Flavorizr config;

  FlavorizrContext buildContext({Set<String> previousFlavors = const {}}) =>
      FlavorizrContext(
        config: config,
        root: root,
        projectRoot: projectRoot,
        logger: TestUtils.quietLogger(),
        previousFlavors: previousFlavors,
      );

  setUp(() {
    final temp = Directory.systemTemp.createTempSync('flavorizr_context_');
    addTearDown(() => temp.deleteSync(recursive: true));

    root = Directory(p.join(temp.path, 'shadow'))..createSync();
    projectRoot = Directory(p.join(temp.path, 'project'))..createSync();
    config = Flavorizr.parse('''
assetsUrl: https://example.com/assets.zip
flavors:
  apple:
    app:
      name: Apple
    android:
      applicationId: com.example.apple
  banana:
    app:
      name: Banana
    android:
      applicationId: com.example.banana
''');
  });

  group('FlavorizrContext', () {
    test('exposes the run inputs', () {
      final ctx = buildContext(previousFlavors: {'apple', 'cherry'});

      expect(ctx.config, same(config));
      expect(ctx.desiredFlavors.keys, ['apple', 'banana']);
      expect(ctx.previousFlavors, {'apple', 'cherry'});
      expect(ctx.root.path, root.path);
      expect(ctx.projectRoot.path, projectRoot.path);
    });

    group('resolve', () {
      test('resolves a project relative path below the shadow root', () {
        final ctx = buildContext();

        expect(
          ctx.resolve('android/app/build.gradle'),
          p.join(root.absolute.path, 'android', 'app', 'build.gradle'),
        );
      });

      test('never resolves against the working directory', () {
        final ctx = buildContext();

        expect(
          p.isWithin(Directory.current.absolute.path, ctx.resolve('lib')),
          isFalse,
        );
        expect(p.isAbsolute(ctx.resolve('lib')), isTrue);
      });
    });

    group('resolveProject', () {
      test('resolves a user input path below the real project root', () {
        final ctx = buildContext();

        expect(
          ctx.resolveProject('assets/icon.png'),
          p.join(projectRoot.absolute.path, 'assets', 'icon.png'),
        );
      });
    });

    group('track', () {
      test('starts without tracked artifacts', () {
        expect(buildContext().tracked, isEmpty);
      });

      test('records the artifacts a processor owns, in order', () {
        final ctx = buildContext()
          ..track(const Artifact('android/app/build.gradle'))
          ..track(const Artifact('lib/flavors.dart'));

        expect(ctx.tracked.map((artifact) => artifact.path), [
          'android/app/build.gradle',
          'lib/flavors.dart',
        ]);
      });

      test('normalizes the path of the artifact', () {
        final ctx = buildContext()..track(const Artifact('android/../lib/a'));

        expect(ctx.tracked.single.path, p.join('lib', 'a'));
      });

      test('rejects an artifact outside the shadow root', () {
        expect(
          () => buildContext().track(const Artifact('../outside.txt')),
          throwsArgumentError,
        );
      });

      test('does not let callers alter the tracked artifacts', () {
        final ctx = buildContext();

        expect(
          () => ctx.tracked.add(const Artifact('lib/a')),
          throwsUnsupportedError,
        );
      });
    });

    group('resource', () {
      const key = ResourceKey<int>('answer');

      test('returns the value of a provided resource', () {
        final ctx = FlavorizrContext(
          config: config,
          root: root,
          projectRoot: projectRoot,
          logger: TestUtils.quietLogger(),
          resources: {key: 42},
        );

        expect(ctx.resource(key), 42);
      });

      test('fails clearly when the resource was not provided', () {
        expect(
          () => buildContext().resource(key),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              contains('answer'),
            ),
          ),
        );
      });
    });

    group('paths escaping their root', () {
      final escapingPaths = {
        'a parent directory': '../outside.txt',
        'a parent directory hidden in a subpath': 'android/../../outside.txt',
        'an absolute path': p.join(Directory.systemTemp.path, 'outside.txt'),
      };

      for (final entry in escapingPaths.entries) {
        test('resolve rejects ${entry.key}', () {
          expect(
            () => buildContext().resolve(entry.value),
            throwsArgumentError,
          );
        });

        test('resolveProject rejects ${entry.key}', () {
          expect(
            () => buildContext().resolveProject(entry.value),
            throwsArgumentError,
          );
        });
      }

      test('a path that goes up and back down stays valid', () {
        expect(
          buildContext().resolve('android/../ios/Podfile'),
          p.join(root.absolute.path, 'ios', 'Podfile'),
        );
      });

      test('the root itself can be resolved', () {
        expect(buildContext().resolve('.'), root.absolute.path);
      });
    });
  });
}
