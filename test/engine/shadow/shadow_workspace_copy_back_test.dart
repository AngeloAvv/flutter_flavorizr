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
import 'package:flutter_flavorizr/src/engine/shadow/copy_back.dart';
import 'package:flutter_flavorizr/src/engine/shadow/shadow_workspace.dart';
import 'package:flutter_flavorizr/src/engine/shadow/workspace_diff.dart';
import 'package:flutter_flavorizr/src/exception/copy_back_interrupted_exception.dart';
import 'package:flutter_flavorizr/src/exception/project_changed_exception.dart';
import 'package:flutter_flavorizr/src/exception/unapproved_conflicts_exception.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'shadow_fixture.dart';

/// Fails on the [failOn]th write, counting from 1, like a full disk would.
class _FailingFiles implements CopyBackFiles {
  final CopyBackFiles _real = const LocalCopyBackFiles();
  final int failOn;
  int calls = 0;

  _FailingFiles({required this.failOn});

  void _tick() {
    if (++calls == failOn) {
      throw const FileSystemException('disk full');
    }
  }

  @override
  Future<void> replace(String staged, String target) async {
    _tick();
    await _real.replace(staged, target);
  }

  @override
  Future<void> remove(String target) async {
    _tick();
    await _real.remove(target);
  }
}

/// Runs [afterReplace] once, right after the first file was replaced.
class _EditingFiles implements CopyBackFiles {
  final CopyBackFiles _real = const LocalCopyBackFiles();
  final void Function() afterReplace;
  bool _done = false;

  _EditingFiles({required this.afterReplace});

  @override
  Future<void> replace(String staged, String target) async {
    await _real.replace(staged, target);

    if (!_done) {
      _done = true;
      afterReplace();
    }
  }

  @override
  Future<void> remove(String target) => _real.remove(target);
}

void main() {
  late ShadowFixture fx;

  setUp(() => fx = ShadowFixture());
  tearDown(() => fx.dispose());

  List<String> leftovers() => Directory(fx.project.root.path)
      .listSync(recursive: true)
      .whereType<File>()
      .map((f) => p.relative(f.path, from: fx.project.root.path))
      .where((path) => path.endsWith('.tmp'))
      .toList();

  group('ShadowWorkspace.copyBack', () {
    test('writes added, modified and deleted files to the project', () async {
      fx.project.write('lib/modified.dart', 'v1');
      fx.project.write('lib/deleted.dart', 'v1');
      fx.project.write('lib/kept.dart', 'kept');
      final shadow = await fx.create(['lib']);
      shadow.write('lib/modified.dart', 'v2');
      shadow.write('lib/added.dart', 'new');
      shadow.delete('lib/deleted.dart');

      final diff = await shadow.diff(
        tracked: [
          const Artifact.local('lib/modified.dart'),
          const Artifact.local('lib/added.dart'),
          const Artifact.local('lib/deleted.dart'),
        ],
      );
      final result = await shadow.copyBack(diff);

      expect(fx.project.read('lib/modified.dart'), 'v2');
      expect(fx.project.read('lib/added.dart'), 'new');
      expect(fx.project.exists('lib/deleted.dart'), isFalse);
      expect(fx.project.read('lib/kept.dart'), 'kept');
      expect(result.applied.map((c) => c.path), [
        'lib/added.dart',
        'lib/deleted.dart',
        'lib/modified.dart',
      ]);
      expect(leftovers(), isEmpty);
    });

    group('folders left empty by a deletion', () {
      Future<WorkspaceDiff> deleting(
        ShadowWorkspace shadow,
        Iterable<String> paths,
      ) => shadow.diff(
        tracked: [for (final path in paths) Artifact.local(path)],
      );

      test('are removed, up to the first one that is not empty', () async {
        fx.project.write('android/app/src/dev/res/mipmap-mdpi/a.png', 'a');
        fx.project.write('android/app/src/dev/res/mipmap-hdpi/a.png', 'a');
        fx.project.write('android/app/src/dev/res/values/mine.xml', 'mine');
        fx.project.write('android/app/src/prod/res/mipmap-mdpi/a.png', 'a');
        fx.project.write('android/app/src/main/AndroidManifest.xml', 'm');
        final shadow = await fx.create(['android/app/src']);
        shadow.delete('android/app/src/dev/res/mipmap-mdpi/a.png');
        shadow.delete('android/app/src/dev/res/mipmap-hdpi/a.png');
        shadow.delete('android/app/src/prod/res/mipmap-mdpi/a.png');

        final result = await shadow.copyBack(
          await deleting(shadow, [
            'android/app/src/dev/res/mipmap-mdpi/a.png',
            'android/app/src/dev/res/mipmap-hdpi/a.png',
            'android/app/src/prod/res/mipmap-mdpi/a.png',
          ]),
        );

        // `prod` had only generated files: the whole flavor folder goes.
        expect(fx.project.exists('android/app/src/prod'), isFalse);
        // `dev` still holds a file of the user: its folder stays, the empty
        // density folders do not.
        expect(fx.project.exists('android/app/src/dev/res/mipmap-mdpi'), false);
        expect(fx.project.exists('android/app/src/dev/res/mipmap-hdpi'), false);
        expect(
          fx.project.read('android/app/src/dev/res/values/mine.xml'),
          'mine',
        );
        expect(
          fx.project.exists('android/app/src/main/AndroidManifest.xml'),
          true,
        );
        expect(result.prunedDirectories, [
          'android/app/src/dev/res/mipmap-hdpi',
          'android/app/src/dev/res/mipmap-mdpi',
          'android/app/src/prod',
          'android/app/src/prod/res',
          'android/app/src/prod/res/mipmap-mdpi',
        ]);
      });

      test('never include the folders the workspace covers', () async {
        fx.project.write('android/app/src/prod/a.png', 'a');
        final shadow = await fx.create(['android/app/src/prod']);
        shadow.delete('android/app/src/prod/a.png');

        await shadow.copyBack(
          await deleting(shadow, ['android/app/src/prod/a.png']),
        );

        expect(fx.project.exists('android/app/src/prod'), isTrue);
        expect(fx.project.exists('android/app/src'), isTrue);
      });

      test('are left alone when a folder was already empty', () async {
        Directory(
          fx.project.abs('android/app/src/other'),
        ).createSync(recursive: true);
        fx.project.write('android/app/src/prod/a.png', 'a');
        final shadow = await fx.create(['android/app/src']);
        shadow.delete('android/app/src/prod/a.png');

        await shadow.copyBack(
          await deleting(shadow, ['android/app/src/prod/a.png']),
        );

        expect(fx.project.exists('android/app/src/prod'), isFalse);
        expect(fx.project.exists('android/app/src/other'), isTrue);
      });

      test('are kept when the copy-back is interrupted', () async {
        fx.project.write('android/app/src/prod/a.png', 'a');
        fx.project.write('android/app/src/qa/b.png', 'b');
        final shadow = await fx.create(['android/app/src']);
        shadow.delete('android/app/src/prod/a.png');
        shadow.delete('android/app/src/qa/b.png');
        final diff = await deleting(shadow, [
          'android/app/src/prod/a.png',
          'android/app/src/qa/b.png',
        ]);

        await expectLater(
          shadow.copyBack(diff, files: _FailingFiles(failOn: 2)),
          throwsA(isA<CopyBackInterruptedException>()),
        );

        // The first deletion was applied, and its folder is now empty: it is
        // still there, because an interrupted copy-back prunes nothing.
        expect(fx.project.exists('android/app/src/prod/a.png'), isFalse);
        expect(fx.project.exists('android/app/src/prod'), isTrue);
        expect(fx.project.exists('android/app/src/qa/b.png'), isTrue);
      });

      test(
        'never include a path the run works on, even inside another',
        () async {
          fx.project.write('android/app/src/prod/a.png', 'a');
          fx.project.write('android/app/src/dev/res/b.png', 'b');
          final shadow = await fx.create(['android/app/src']);
          shadow.delete('android/app/src/prod/a.png');
          shadow.delete('android/app/src/dev/res/b.png');

          final result = await copyBackChanges(
            projectRoot: fx.project.root,
            shadowRoot: shadow.root,
            diff: await deleting(shadow, [
              'android/app/src/prod/a.png',
              'android/app/src/dev/res/b.png',
            ]),
            pruneBelow: ['android/app/src', 'android/app/src/prod'],
          );

          expect(fx.project.exists('android/app/src/prod'), isTrue);
          expect(fx.project.exists('android/app/src/dev'), isFalse);
          expect(result.prunedDirectories, [
            'android/app/src/dev',
            'android/app/src/dev/res',
          ]);
        },
      );

      test(
        'are kept by copyBackChanges unless it is told where to prune',
        () async {
          fx.project.write('lib/sub/a.dart', 'a');
          final shadow = await fx.create(['lib']);
          shadow.delete('lib/sub/a.dart');

          await copyBackChanges(
            projectRoot: fx.project.root,
            shadowRoot: shadow.root,
            diff: await deleting(shadow, ['lib/sub/a.dart']),
          );

          expect(fx.project.exists('lib/sub'), isTrue);
        },
      );
    });

    test('creates the missing folders of a new file', () async {
      final shadow = await fx.create(['android/app/src']);
      shadow.write('android/app/src/dev/res/values/strings.xml', '<r/>');

      final diff = await shadow.diff(
        tracked: [
          const Artifact.managed('android/app/src/dev/res/values/strings.xml'),
        ],
      );
      await shadow.copyBack(diff);

      expect(
        fx.project.read('android/app/src/dev/res/values/strings.xml'),
        '<r/>',
      );
    });

    test('copies binary content byte for byte', () async {
      final shadow = await fx.create(['assets']);
      final bytes = List<int>.generate(512, (i) => i % 256);
      File(p.join(shadow.root.path, 'assets', 'icon.png'))
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes);

      final diff = await shadow.diff(
        tracked: [const Artifact.local('assets/icon.png')],
      );
      await shadow.copyBack(diff);

      expect(File(fx.project.abs('assets/icon.png')).readAsBytesSync(), bytes);
    });

    test('does not write what ownership says to keep', () async {
      fx.project.write('lib/main.dart', 'mine');
      final shadow = await fx.create(['lib']);
      shadow.write('lib/main.dart', 'template');
      shadow.write('lib/stray.dart', 'x');

      final diff = await shadow.diff(
        tracked: [const Artifact.scaffold('lib/main.dart')],
      );
      final result = await shadow.copyBack(diff);

      expect(fx.project.read('lib/main.dart'), 'mine');
      expect(fx.project.exists('lib/stray.dart'), isFalse);
      expect(result.applied, isEmpty);
    });

    test('does nothing for an empty diff', () async {
      fx.project.write('lib/a.dart', 'a');
      final shadow = await fx.create(['lib']);

      final result = await shadow.copyBack(await shadow.diff());

      expect(result.applied, isEmpty);
      expect(fx.project.read('lib/a.dart'), 'a');
    });

    group('when a real file changed since it was copied', () {
      test('aborts and writes nothing', () async {
        fx.project.write('lib/a.dart', 'a1');
        fx.project.write('lib/b.dart', 'b1');
        final shadow = await fx.create(['lib']);
        shadow.write('lib/a.dart', 'a2');
        shadow.write('lib/b.dart', 'b2');
        final diff = await shadow.diff(
          tracked: [
            const Artifact.local('lib/a.dart'),
            const Artifact.local('lib/b.dart'),
          ],
        );

        fx.project.write('lib/b.dart', 'edited meanwhile');

        await expectLater(
          shadow.copyBack(diff),
          throwsA(
            isA<ProjectChangedException>()
                .having((e) => e.paths, 'paths', ['lib/b.dart'])
                .having(
                  (e) => e.toString(),
                  'message',
                  allOf(
                    contains('lib/b.dart'),
                    contains('nothing was written'),
                  ),
                ),
          ),
        );
        expect(fx.project.read('lib/a.dart'), 'a1');
        expect(fx.project.read('lib/b.dart'), 'edited meanwhile');
        expect(leftovers(), isEmpty);
      });

      test('aborts when a file to create appeared meanwhile', () async {
        final shadow = await fx.create(['lib']);
        shadow.write('lib/new.dart', 'mine');
        final diff = await shadow.diff(
          tracked: [const Artifact.local('lib/new.dart')],
        );

        fx.project.write('lib/new.dart', 'theirs');

        await expectLater(
          shadow.copyBack(diff),
          throwsA(isA<ProjectChangedException>()),
        );
        expect(fx.project.read('lib/new.dart'), 'theirs');
      });

      test('aborts when a file to delete changed meanwhile', () async {
        fx.project.write('lib/old.dart', 'v1');
        final shadow = await fx.create(['lib']);
        shadow.delete('lib/old.dart');
        final diff = await shadow.diff(
          tracked: [const Artifact.local('lib/old.dart')],
        );

        fx.project.write('lib/old.dart', 'v2');

        await expectLater(
          shadow.copyBack(diff),
          throwsA(isA<ProjectChangedException>()),
        );
        expect(fx.project.read('lib/old.dart'), 'v2');
      });

      test('ignores files the diff does not write', () async {
        fx.project.write('lib/a.dart', 'a1');
        fx.project.write('lib/other.dart', 'o1');
        final shadow = await fx.create(['lib']);
        shadow.write('lib/a.dart', 'a2');
        final diff = await shadow.diff(
          tracked: [const Artifact.local('lib/a.dart')],
        );

        fx.project.write('lib/other.dart', 'o2');
        await shadow.copyBack(diff);

        expect(fx.project.read('lib/a.dart'), 'a2');
      });
    });

    group('conflicts', () {
      Future<(ShadowWorkspace, WorkspaceDiff)> conflicting() async {
        fx.project.write('lib/flavors.dart', 'by hand');
        fx.project.write('lib/ok.dart', 'v1');
        final shadow = await fx.create(['lib']);
        shadow.write('lib/flavors.dart', 'generated');
        shadow.write('lib/ok.dart', 'v2');

        return (
          shadow,
          await shadow.diff(
            tracked: [
              const Artifact.managed('lib/flavors.dart'),
              const Artifact.local('lib/ok.dart'),
            ],
          ),
        );
      }

      test('stop copy-back unless approved, writing nothing', () async {
        final (shadow, diff) = await conflicting();

        await expectLater(
          shadow.copyBack(diff),
          throwsA(
            isA<UnapprovedConflictsException>().having(
              (e) => e.paths,
              'paths',
              ['lib/flavors.dart'],
            ),
          ),
        );
        expect(fx.project.read('lib/flavors.dart'), 'by hand');
        expect(fx.project.read('lib/ok.dart'), 'v1');
      });

      test('are written when approved', () async {
        final (shadow, diff) = await conflicting();

        final result = await shadow.copyBack(
          diff,
          approvedConflicts: {'lib/flavors.dart'},
        );

        expect(fx.project.read('lib/flavors.dart'), 'generated');
        expect(fx.project.read('lib/ok.dart'), 'v2');
        expect(result.applied, hasLength(2));
      });

      test('approving a path that is not a conflict changes nothing', () async {
        fx.project.write('lib/main.dart', 'mine');
        final shadow = await fx.create(['lib']);
        shadow.write('lib/main.dart', 'template');
        final diff = await shadow.diff(
          tracked: [const Artifact.scaffold('lib/main.dart')],
        );

        await shadow.copyBack(diff, approvedConflicts: {'lib/main.dart'});

        expect(fx.project.read('lib/main.dart'), 'mine');
      });
    });

    group('symbolic links', () {
      test('are never written through, even when approved', () async {
        final outside = Directory(p.join(fx.scratch.path, 'outside'))
          ..createSync();
        Link(fx.project.abs('ios')).createSync(outside.path);
        final shadow = await fx.create(['ios/Runner/Info.plist']);
        shadow.write('ios/Runner/Info.plist', 'x');
        final diff = await shadow.diff(
          tracked: [const Artifact.managed('ios/Runner/Info.plist')],
        );

        final result = await shadow.copyBack(
          diff,
          approvedConflicts: {'ios/Runner/Info.plist'},
        );

        expect(result.applied, isEmpty);
        expect(outside.listSync(), isEmpty);
      }, skip: Platform.isWindows ? 'creating links needs privileges' : false);

      test('turned up in the project since the copy abort copy-back', () async {
        final outside = Directory(p.join(fx.scratch.path, 'outside'))
          ..createSync();
        fx.project.write('ios/Runner/Info.plist', 'v1');
        final shadow = await fx.create(['ios']);
        shadow.write('ios/Runner/Info.plist', 'v2');
        final diff = await shadow.diff(
          tracked: [const Artifact.local('ios/Runner/Info.plist')],
        );

        Directory(fx.project.abs('ios')).deleteSync(recursive: true);
        Link(fx.project.abs('ios')).createSync(outside.path);

        await expectLater(
          shadow.copyBack(diff),
          throwsA(isA<ProjectChangedException>()),
        );
        expect(outside.listSync(), isEmpty);
      }, skip: Platform.isWindows ? 'creating links needs privileges' : false);
    });

    group('symbolic links in the shadow', () {
      late Directory outside;

      setUp(() {
        outside = Directory(p.join(fx.scratch.path, 'outside'))..createSync();
      });

      test('are rejected even when they hold the reviewed bytes', () async {
        fx.project.write('lib/a.dart', 'a1');
        final shadow = await fx.create(['lib']);
        shadow.write('lib/a.dart', 'a2');
        final diff = await shadow.diff(
          tracked: [const Artifact.local('lib/a.dart')],
        );

        // Same bytes as the reviewed ones, but living outside the workspace.
        final target = File(p.join(outside.path, 'a2.dart'))
          ..writeAsStringSync('a2');
        File(p.join(shadow.root.path, 'lib', 'a.dart')).deleteSync();
        Link(p.join(shadow.root.path, 'lib', 'a.dart')).createSync(target.path);

        await expectLater(shadow.copyBack(diff), throwsStateError);
        expect(fx.project.read('lib/a.dart'), 'a1');
        expect(leftovers(), isEmpty);
      });

      test('are rejected when a parent folder is one', () async {
        fx.project.write('lib/sub/a.dart', 'a1');
        final shadow = await fx.create(['lib']);
        shadow.write('lib/sub/a.dart', 'a2');
        final diff = await shadow.diff(
          tracked: [const Artifact.local('lib/sub/a.dart')],
        );

        File(p.join(outside.path, 'a.dart')).writeAsStringSync('a2');
        Directory(
          p.join(shadow.root.path, 'lib', 'sub'),
        ).deleteSync(recursive: true);
        Link(p.join(shadow.root.path, 'lib', 'sub')).createSync(outside.path);

        await expectLater(shadow.copyBack(diff), throwsStateError);
        expect(fx.project.read('lib/sub/a.dart'), 'a1');
      });

      test(
        'a dangling link at the staging path is not written through',
        () async {
          fx.project.write('lib/a.dart', 'a1');
          final shadow = await fx.create(['lib']);
          shadow.write('lib/a.dart', 'a2');
          final diff = await shadow.diff(
            tracked: [const Artifact.local('lib/a.dart')],
          );
          final victim = File(p.join(outside.path, 'victim.txt'));

          // The first name the copy-back would try.
          Link(
            fx.project.abs('lib/.a.dart.fixed.0.tmp'),
          ).createSync(victim.path);

          await copyBackChanges(
            projectRoot: fx.project.root,
            shadowRoot: shadow.root,
            diff: diff,
            stagingSuffix: (attempt) => 'fixed.$attempt',
          );

          expect(victim.existsSync(), isFalse);
          expect(fx.project.read('lib/a.dart'), 'a2');
        },
      );
    }, skip: Platform.isWindows ? 'creating links needs privileges' : false);

    group('when the workspace changed after the diff', () {
      test('refuses to write something nobody reviewed', () async {
        fx.project.write('lib/a.dart', 'a1');
        final shadow = await fx.create(['lib']);
        shadow.write('lib/a.dart', 'a2');
        final diff = await shadow.diff(
          tracked: [const Artifact.local('lib/a.dart')],
        );

        shadow.write('lib/a.dart', 'sneaky');

        await expectLater(shadow.copyBack(diff), throwsStateError);
        expect(fx.project.read('lib/a.dart'), 'a1');
        expect(leftovers(), isEmpty);
      });
    });

    group('when writing is interrupted', () {
      Future<(ShadowWorkspace, WorkspaceDiff)> three() async {
        fx.project.write('lib/a.dart', 'a1');
        fx.project.write('lib/b.dart', 'b1');
        fx.project.write('lib/c.dart', 'c1');
        final shadow = await fx.create(['lib']);
        shadow.write('lib/a.dart', 'a2');
        shadow.write('lib/b.dart', 'b2');
        shadow.write('lib/c.dart', 'c2');

        return (
          shadow,
          await shadow.diff(
            tracked: [
              const Artifact.local('lib/a.dart'),
              const Artifact.local('lib/b.dart'),
              const Artifact.local('lib/c.dart'),
            ],
          ),
        );
      }

      test('lists the files already applied and the ones left', () async {
        final (shadow, diff) = await three();

        await expectLater(
          shadow.copyBack(diff, files: _FailingFiles(failOn: 2)),
          throwsA(
            isA<CopyBackInterruptedException>()
                .having((e) => e.applied, 'applied', ['lib/a.dart'])
                .having((e) => e.pending, 'pending', [
                  'lib/b.dart',
                  'lib/c.dart',
                ])
                .having((e) => e.cause, 'cause', isA<FileSystemException>())
                .having(
                  (e) => e.toString(),
                  'message',
                  allOf(contains('lib/a.dart'), contains('lib/b.dart')),
                ),
          ),
        );
        expect(fx.project.read('lib/a.dart'), 'a2');
        expect(fx.project.read('lib/b.dart'), 'b1');
        expect(fx.project.read('lib/c.dart'), 'c1');
      });

      test('re-checks each file right before its own rename', () async {
        final (shadow, diff) = await three();
        final files = _EditingFiles(
          // After a is written, someone edits c.
          afterReplace: () => fx.project.write('lib/c.dart', 'edited late'),
        );

        await expectLater(
          shadow.copyBack(diff, files: files),
          throwsA(
            isA<CopyBackInterruptedException>()
                .having((e) => e.applied, 'applied', [
                  'lib/a.dart',
                  'lib/b.dart',
                ])
                .having((e) => e.pending, 'pending', ['lib/c.dart'])
                .having(
                  (e) => e.cause,
                  'cause',
                  isA<ProjectChangedException>(),
                ),
          ),
        );
        expect(fx.project.read('lib/c.dart'), 'edited late');
        expect(leftovers(), isEmpty);
      });

      test('leaves no staged file behind', () async {
        final (shadow, diff) = await three();

        await expectLater(
          shadow.copyBack(diff, files: _FailingFiles(failOn: 2)),
          throwsA(isA<CopyBackInterruptedException>()),
        );

        expect(leftovers(), isEmpty);
      });

      test('on the first file applies nothing and lists none', () async {
        final (shadow, diff) = await three();

        await expectLater(
          shadow.copyBack(diff, files: _FailingFiles(failOn: 1)),
          throwsA(
            isA<CopyBackInterruptedException>().having(
              (e) => e.applied,
              'applied',
              isEmpty,
            ),
          ),
        );
        expect(fx.project.read('lib/a.dart'), 'a1');
      });
    });
  });
}
