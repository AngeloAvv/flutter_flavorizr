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
import 'package:test/test.dart';
import 'package:path/path.dart' as p;

import '../test_utils.dart';

void main() {
  late Directory root;
  late Directory projectRoot;
  late FlavorizrConfig config;

  FlavorizrContext buildContext({
    Set<String> previousFlavors = const {},
    String? processorId,
    Map<String, Map<String, Set<String>>> previousObjects = const {},
    Set<String> previousFiles = const {},
  }) => FlavorizrContext(
    config: config,
    root: root,
    projectRoot: projectRoot,
    logger: TestUtils.quietLogger(),
    previousFlavors: previousFlavors,
    processorId: processorId,
    previousObjects: previousObjects,
    previousFiles: previousFiles,
  );

  setUp(() {
    final temp = Directory.systemTemp.createTempSync('flavorizr_context_');
    addTearDown(() => temp.deleteSync(recursive: true));

    root = Directory(p.join(temp.path, 'shadow'))..createSync();
    projectRoot = Directory(p.join(temp.path, 'project'))..createSync();
    config = FlavorizrConfig.parse('''
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

    group('hasPreviousFile', () {
      test('is whether the lock recorded the file, or a file below the folder', () {
        final ctx = buildContext(
          previousFiles: {'a/set/Contents.json', 'b.txt'},
        );

        expect(ctx.hasPreviousFile('b.txt'), isTrue);
        expect(ctx.hasPreviousFile('a/set'), isTrue);
        expect(ctx.hasPreviousFile('a/set/'), isTrue);
        expect(ctx.hasPreviousFile('a/se'), isFalse);
        expect(ctx.hasPreviousFile('c'), isFalse);
      });

      test('is false on the first run, and for a path that is not one', () {
        expect(buildContext().hasPreviousFile('a'), isFalse);
        expect(
          buildContext(previousFiles: {'a'}).hasPreviousFile('../a'),
          isFalse,
        );
      });
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

        // The root is where the context resolves, wherever the temporary
        // directory is: it may well live inside the working directory.
        expect(ctx.resolve('lib'), p.join(root.absolute.path, 'lib'));
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
          ..track(const Artifact.patched('android/app/build.gradle'))
          ..track(const Artifact.managed('lib/flavors.dart'));

        expect(ctx.tracked.map((artifact) => artifact.path), [
          'android/app/build.gradle',
          'lib/flavors.dart',
        ]);
      });

      test('stores the very artifact it was given', () {
        const artifact = Artifact.managed('lib/a');
        final ctx = buildContext()..track(artifact);

        expect(ctx.tracked.single, same(artifact));
      });

      test('rejects an artifact outside the shadow root', () {
        expect(
          () => buildContext().track(const Artifact.managed('../outside.txt')),
          throwsArgumentError,
        );
      });

      test('does not let callers alter the tracked artifacts', () {
        final ctx = buildContext();

        expect(
          () => ctx.tracked.add(const Artifact.managed('lib/a')),
          throwsUnsupportedError,
        );
      });
    });

    group('trackFor', () {
      test('tracks the artifacts and remembers whose they are', () {
        final ctx = buildContext()
          ..trackFor('android', [const Artifact.managed('lib/a')])
          ..trackFor('ios', [const Artifact.managed('lib/b')]);

        expect(ctx.tracked.map((artifact) => artifact.path), [
          'lib/a',
          'lib/b',
        ]);
        expect(
          ctx.trackedByProcessor.map(
            (id, artifacts) =>
                MapEntry(id, [for (final a in artifacts) a.path]),
          ),
          {
            'android': ['lib/a'],
            'ios': ['lib/b'],
          },
        );
      });

      test('remembers a processor that tracked nothing', () {
        final ctx = buildContext()..trackFor('android', const []);

        expect(ctx.trackedByProcessor, {'android': isEmpty});
      });

      test('does not attribute what is tracked directly', () {
        final ctx = buildContext()..track(const Artifact.managed('lib/a'));

        expect(ctx.trackedByProcessor, isEmpty);
      });

      test('rejects an artifact outside the shadow root', () {
        expect(
          () => buildContext().trackFor('android', [
            const Artifact.managed('../outside.txt'),
          ]),
          throwsArgumentError,
        );
      });

      test('does not let callers alter what was attributed', () {
        final ctx = buildContext()..trackFor('android', const []);

        expect(
          () => ctx.trackedByProcessor['ios'] = [],
          throwsUnsupportedError,
        );
        expect(
          () => ctx.trackedByProcessor['android']!.add(
            const Artifact.managed('lib/a'),
          ),
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

    group('objects', () {
      const pbxproj = 'ios/Runner.xcodeproj/project.pbxproj';

      test('a processor reads the UUIDs the lock recorded for it', () {
        final ctx = buildContext(
          processorId: 'ios:buildTargets',
          previousObjects: {
            'ios:buildTargets': {
              pbxproj: {'AAAAAAAAAAAAAAAAAAAAAAAA'},
            },
            'ios:xcconfig': {
              pbxproj: {'BBBBBBBBBBBBBBBBBBBBBBBB'},
            },
          },
        );

        expect(ctx.previousObjectsOf(pbxproj), {'AAAAAAAAAAAAAAAAAAAAAAAA'});
        expect(ctx.previousObjectsOf('ios/Other.pbxproj'), isEmpty);
      });

      test('the paths of the lock are read in their canonical form', () {
        final ctx = buildContext(
          processorId: 'ios:buildTargets',
          previousObjects: {
            'ios:buildTargets': {
              r'ios\Runner.xcodeproj\project.pbxproj': {
                'AAAAAAAAAAAAAAAAAAAAAAAA',
              },
              '../escape/project.pbxproj': {'CCCCCCCCCCCCCCCCCCCCCCCC'},
            },
          },
        );

        expect(ctx.previousObjectsOf(pbxproj), {'AAAAAAAAAAAAAAAAAAAAAAAA'});
        expect(ctx.previousObjectsOf('escape/project.pbxproj'), isEmpty);
      });

      test('what a processor owns is kept apart from the others', () {
        final ctx = buildContext(processorId: 'ios:buildTargets');

        ctx.ownObjects(pbxproj, ['BBBBBBBBBBBBBBBBBBBBBBBB']);
        ctx.ownObjects(pbxproj, ['AAAAAAAAAAAAAAAAAAAAAAAA']);

        expect(ctx.ownedObjects, {
          'ios:buildTargets': {
            pbxproj: {'AAAAAAAAAAAAAAAAAAAAAAAA', 'BBBBBBBBBBBBBBBBBBBBBBBB'},
          },
        });
      });

      test('owning nothing is still said', () {
        final ctx = buildContext(processorId: 'ios:buildTargets');

        ctx.ownObjects(pbxproj, const []);

        expect(ctx.ownedObjects, {
          'ios:buildTargets': {pbxproj: <String>{}},
        });
      });

      test('the engine hands the objects of a step back to the run', () {
        final ctx = buildContext();

        ctx.ownObjectsFor('ios:buildTargets', {
          pbxproj: {'AAAAAAAAAAAAAAAAAAAAAAAA'},
        });

        expect(ctx.ownedObjects, {
          'ios:buildTargets': {
            pbxproj: {'AAAAAAAAAAAAAAAAAAAAAAAA'},
          },
        });
      });

      test('only the context of a processor reads or owns objects', () {
        final ctx = buildContext();

        expect(() => ctx.previousObjectsOf(pbxproj), throwsStateError);
        expect(() => ctx.ownObjects(pbxproj, const []), throwsStateError);
      });

      test('a path that leaves the project cannot be owned', () {
        final ctx = buildContext(processorId: 'ios:buildTargets');

        expect(
          () => ctx.ownObjects('../outside.pbxproj', const []),
          throwsArgumentError,
        );
        expect(ctx.ownedObjects, isEmpty);
      });

      test('the views are read only', () {
        final ctx = buildContext(processorId: 'ios:buildTargets');
        ctx.ownObjects(pbxproj, ['AAAAAAAAAAAAAAAAAAAAAAAA']);

        expect(() => ctx.ownedObjects['x'] = {}, throwsUnsupportedError);
        expect(
          () => ctx.ownedObjects['ios:buildTargets']![pbxproj]!.add('X'),
          throwsUnsupportedError,
        );
        expect(
          () => ctx.previousObjectsOf(pbxproj).add('X'),
          throwsUnsupportedError,
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
