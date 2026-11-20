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
import 'package:flutter_flavorizr/src/engine/lock/flavorizr_lock.dart';
import 'package:flutter_flavorizr/src/engine/ownership.dart';
import 'package:flutter_flavorizr/src/engine/reconcile/lock_update.dart';
import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

const pbxproj = 'ios/Runner.xcodeproj/project.pbxproj';
const patchedPbxproj = Artifact.patched(pbxproj);

FlavorizrLock lockOf(Map<String, ProcessorLock> processors) =>
    FlavorizrLock(flavorizrVersion: '3.0.0', processors: processors);

FlavorizrLock update({
  FlavorizrLock? previous,
  Map<String, Iterable<Artifact>> produced = const {},
  Map<String, Map<String, Map<String, String>>> keys = const {},
  Set<String> retained = const {},
}) => updateLock(
  previous: previous,
  flavorizrVersion: '3.0.0',
  produced: produced,
  ownedHashes: {pbxproj: 'h'},
  desiredFlavors: const {},
  availableProcessors: const {'ios:buildTargets', 'macos:buildTargets'},
  retained: retained,
  ownedKeys: keys,
);

ProcessorLock recorded(Map<String, String> keys) => ProcessorLock(
  files: {pbxproj: LockedFile(ownership: Ownership.patched, hash: 'h')},
  keys: {pbxproj: keys},
);

void main() {
  group('FlavorizrContext, owned keys', () {
    late Directory temp;

    FlavorizrContext build({
      String? processorId = 'ios:buildTargets',
      Map<String, Map<String, Map<String, String>>> previousKeys = const {},
    }) => FlavorizrContext(
      config: FlavorizrConfig.parse('''
flavors:
  apple:
    app:
      name: Apple
    ios:
      bundleId: com.example.apple
'''),
      root: Directory(p.join(temp.path, 'shadow'))..createSync(),
      projectRoot: Directory(p.join(temp.path, 'project'))..createSync(),
      logger: Logger(level: Level.quiet),
      processorId: processorId,
      previousKeys: previousKeys,
    );

    setUp(() {
      temp = Directory.systemTemp.createTempSync('flavorizr_keys_');
      addTearDown(() => temp.deleteSync(recursive: true));
    });

    test('a processor reads the keys the lock recorded for it', () {
      final ctx = build(
        previousKeys: {
          'ios:buildTargets': {
            pbxproj: {'project/Debug-apple/SWIFT_VERSION': 'sha256:a'},
          },
          'ios:xcconfig': {
            pbxproj: {'project/Debug-apple/OTHER': 'sha256:b'},
          },
        },
      );

      expect(ctx.previousKeysOf(pbxproj), {
        'project/Debug-apple/SWIFT_VERSION': 'sha256:a',
      });
      expect(ctx.previousKeysOf('ios/Other.pbxproj'), isEmpty);
    });

    test('the paths of the lock are read in their canonical form', () {
      final ctx = build(
        previousKeys: {
          'ios:buildTargets': {
            r'ios\Runner.xcodeproj\project.pbxproj': {'k': 'sha256:a'},
            '../escape/project.pbxproj': {'k': 'sha256:b'},
          },
        },
      );

      expect(ctx.previousKeysOf(pbxproj), {'k': 'sha256:a'});
      expect(ctx.previousKeysOf('escape/project.pbxproj'), isEmpty);
    });

    test('a processor reads the files the lock recorded keys for it', () {
      final ctx = build(
        previousKeys: {
          'ios:buildTargets': {
            pbxproj: {'k': 'sha256:a'},
            r'ios\Other.pbxproj': {'k': 'sha256:b'},
            '../escape/project.pbxproj': {'k': 'sha256:c'},
          },
          'ios:xcconfig': {
            'ios/Flutter/Debug.xcconfig': {'k': 'sha256:d'},
          },
        },
      );

      expect(ctx.previousKeyFiles, {pbxproj, 'ios/Other.pbxproj'});
      expect(build().previousKeyFiles, isEmpty);
      expect(() => build(processorId: null).previousKeyFiles, throwsStateError);
    });

    test('what a processor owns is added up by file', () {
      final ctx = build();

      ctx.ownKeys(pbxproj, {'b': 'sha256:b'});
      ctx.ownKeys(pbxproj, {'a': 'sha256:a'});

      expect(ctx.ownedKeys, {
        'ios:buildTargets': {
          pbxproj: {'a': 'sha256:a', 'b': 'sha256:b'},
        },
      });
    });

    test('owning nothing is still said', () {
      final ctx = build();

      ctx.ownKeys(pbxproj, const {});

      expect(ctx.ownedKeys, {
        'ios:buildTargets': {pbxproj: <String, String>{}},
      });
    });

    test('the engine hands the keys of a step back to the run', () {
      final ctx = build(processorId: null);

      ctx.ownKeysFor('ios:buildTargets', {
        pbxproj: {'a': 'sha256:a'},
      });

      expect(ctx.ownedKeys, {
        'ios:buildTargets': {
          pbxproj: {'a': 'sha256:a'},
        },
      });
    });

    test('only the context of a processor reads or owns keys', () {
      final ctx = build(processorId: null);

      expect(() => ctx.previousKeysOf(pbxproj), throwsStateError);
      expect(() => ctx.ownKeys(pbxproj, const {}), throwsStateError);
    });

    test('a file found edited by hand is told in its canonical form', () {
      final ctx = build();

      ctx.reportEdited(r'ios\Runner.xcodeproj\project.pbxproj');

      expect(ctx.edited, {pbxproj});
      expect(() => ctx.reportEdited('../escape'), throwsArgumentError);
    });

    test('a path that leaves the project cannot be owned', () {
      final ctx = build();

      expect(
        () => ctx.ownKeys('../escape/project.pbxproj', const {}),
        throwsArgumentError,
      );
    });
  });

  group('updateLock, owned keys', () {
    final produced = {
      'ios:buildTargets': [patchedPbxproj],
    };

    test('records the keys a processor says it owns, by file', () {
      final lock = update(
        produced: produced,
        keys: {
          'ios:buildTargets': {
            pbxproj: {'a': 'sha256:a'},
          },
        },
      );

      expect(lock.processors['ios:buildTargets']!.keys, {
        pbxproj: {'a': 'sha256:a'},
      });
    });

    test('are rebuilt: a key no longer owned leaves the record', () {
      final lock = update(
        previous: lockOf({
          'ios:buildTargets': recorded({'a': 'sha256:a', 'b': 'sha256:b'}),
        }),
        produced: produced,
        keys: {
          'ios:buildTargets': {
            pbxproj: {'a': 'sha256:a'},
          },
        },
      );

      expect(lock.processors['ios:buildTargets']!.keys, {
        pbxproj: {'a': 'sha256:a'},
      });
    });

    test('a processor that says nothing keeps what the lock had', () {
      final lock = update(
        previous: lockOf({
          'ios:buildTargets': recorded({'a': 'sha256:a'}),
        }),
        produced: produced,
      );

      expect(lock.processors['ios:buildTargets']!.keys, {
        pbxproj: {'a': 'sha256:a'},
      });
    });

    test('owning no key anymore forgets them all', () {
      final lock = update(
        previous: lockOf({
          'ios:buildTargets': recorded({'a': 'sha256:a'}),
        }),
        produced: produced,
        keys: {
          'ios:buildTargets': {pbxproj: <String, String>{}},
        },
      );

      expect(lock.processors['ios:buildTargets']!.keys, isEmpty);
    });

    test('the keys of a retained file are the ones the lock had', () {
      final lock = update(
        previous: lockOf({
          'ios:buildTargets': recorded({'a': 'sha256:a'}),
        }),
        produced: produced,
        retained: {pbxproj},
        keys: {
          'ios:buildTargets': {
            pbxproj: {'a': 'sha256:new'},
          },
        },
      );

      expect(lock.processors['ios:buildTargets']!.keys, {
        pbxproj: {'a': 'sha256:a'},
      });
    });

    test('keys said about a file the processor does not track are not '
        'kept', () {
      final lock = update(
        produced: {'ios:buildTargets': const <Artifact>[]},
        keys: {
          'ios:buildTargets': {
            pbxproj: {'a': 'sha256:a'},
          },
        },
      );

      expect(lock.processors['ios:buildTargets'], isNull);
    });

    test('a file that is no longer tracked takes its keys with it', () {
      final lock = update(
        previous: lockOf({
          'ios:buildTargets': recorded({'a': 'sha256:a'}),
        }),
        produced: {
          'ios:buildTargets': [const Artifact.scaffold('other.txt')],
        },
      );

      expect(lock.processors['ios:buildTargets']!.keys, isEmpty);
    });

    test('the other processors keep their keys in a partial run', () {
      final lock = update(
        previous: lockOf({
          'ios:buildTargets': recorded({'a': 'sha256:a'}),
          'macos:buildTargets': recorded({'m': 'sha256:m'}),
        }),
        produced: {
          'macos:buildTargets': [patchedPbxproj],
        },
        keys: {
          'macos:buildTargets': {
            pbxproj: {'m': 'sha256:n'},
          },
        },
      );

      expect(lock.processors['ios:buildTargets']!.keys, {
        pbxproj: {'a': 'sha256:a'},
      });
      expect(lock.processors['macos:buildTargets']!.keys, {
        pbxproj: {'m': 'sha256:n'},
      });
    });

    test('the keys of a local file are recorded as the processor says them, '
        'and are how it remembers the copies it made', () {
      const copy = Artifact.local('android/app/src/apple/copy.json');
      final lock = update(
        produced: {
          'ios:buildTargets': [copy],
        },
        keys: {
          'ios:buildTargets': {
            copy.path: {'copy': 'sha256:a'},
          },
        },
      );

      expect(lock.processors['ios:buildTargets']!.files, isEmpty);
      expect(lock.processors['ios:buildTargets']!.keys, {
        copy.path: {'copy': 'sha256:a'},
      });
    });

    test('the keys the lock had for a local file are not carried over: what '
        'the processor stops saying is forgotten', () {
      const copy = Artifact.local('android/app/src/apple/copy.json');
      final lock = update(
        previous: lockOf({
          'ios:buildTargets': ProcessorLock(
            keys: {
              copy.path: {'copy': 'sha256:a'},
            },
          ),
        }),
        produced: {
          'ios:buildTargets': [copy],
        },
      );

      expect(lock.processors['ios:buildTargets'], isNull);
    });

    test('a local file the processor stops tracking takes its keys with '
        'it', () {
      final lock = update(
        previous: lockOf({
          'ios:buildTargets': ProcessorLock(
            keys: {
              'android/app/src/apple/copy.json': {'copy': 'sha256:a'},
            },
          ),
        }),
        produced: {'ios:buildTargets': const <Artifact>[]},
      );

      expect(lock.processors['ios:buildTargets'], isNull);
    });
  });
}
