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
import 'package:flutter_flavorizr/src/engine/ownership.dart';
import 'package:flutter_flavorizr/src/engine/shadow/file_digest.dart';
import 'package:flutter_flavorizr/src/engine/shadow/workspace_diff.dart';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;

import 'shadow_fixture.dart';

void main() {
  late ShadowFixture fx;

  setUp(() => fx = ShadowFixture());
  tearDown(() => fx.dispose());

  Map<String, ChangeKind> kinds(WorkspaceDiff diff) => {
    for (final change in diff.changes) change.path: change.kind,
  };

  group('ShadowWorkspace.diff', () {
    test('is empty when processors changed nothing', () async {
      fx.project.write('lib/a.dart', 'a');
      final shadow = await fx.create(['lib']);

      final diff = await shadow.diff();

      expect(diff.isEmpty, isTrue);
      expect(diff.changes, isEmpty);
    });

    test('tells added, modified and deleted files apart, sorted', () async {
      fx.project.write('lib/kept.dart', 'kept');
      fx.project.write('lib/modified.dart', 'before');
      fx.project.write('lib/deleted.dart', 'gone');
      final shadow = await fx.create(['lib']);

      shadow.write('lib/modified.dart', 'after');
      shadow.write('lib/added.dart', 'new');
      shadow.delete('lib/deleted.dart');

      final diff = await shadow.diff();

      expect(kinds(diff), {
        'lib/added.dart': ChangeKind.added,
        'lib/deleted.dart': ChangeKind.deleted,
        'lib/modified.dart': ChangeKind.modified,
      });
      expect(diff.changes.map((c) => c.path), [
        'lib/added.dart',
        'lib/deleted.dart',
        'lib/modified.dart',
      ]);
    });

    test('a file rewritten with identical content is not a change', () async {
      fx.project.write('lib/a.dart', 'same');
      final shadow = await fx.create(['lib']);

      shadow.write('lib/a.dart', 'same');

      expect((await shadow.diff()).isEmpty, isTrue);
    });

    test('reports the digests before and after', () async {
      fx.project.write('lib/a.dart', 'before');
      final shadow = await fx.create(['lib']);

      shadow.write('lib/a.dart', 'after');
      shadow.write('lib/b.dart', 'b');

      final changes = {
        for (final c in (await shadow.diff()).changes) c.path: c,
      };

      expect(changes['lib/a.dart']!.before, digestOf('before'.codeUnits));
      expect(changes['lib/a.dart']!.after, digestOf('after'.codeUnits));
      expect(changes['lib/b.dart']!.before, isNull);
      expect(changes['lib/b.dart']!.after, digestOf('b'.codeUnits));
    });

    test('ignores what processors wrote in ignored folders', () async {
      fx.project.write('ios/Runner/Info.plist', 'plist');
      final shadow = await fx.create(['ios']);

      shadow.write('ios/Pods/Manifest.lock', 'x');
      shadow.write('ios/Flutter/ephemeral/a', 'x');
      shadow.write('build/out.txt', 'x');

      expect((await shadow.diff()).isEmpty, isTrue);
    });

    test('does not treat a new empty folder as a change', () async {
      final shadow = await fx.create(['lib']);

      Directory(
        p.join(shadow.root.path, 'lib', 'empty'),
      ).createSync(recursive: true);

      expect((await shadow.diff()).isEmpty, isTrue);
    });
  });

  group('ownership', () {
    ChangeDisposition? disposition(WorkspaceDiff diff, String path) =>
        diff.changes.singleWhere((c) => c.path == path).disposition;

    test('a file written outside the whitelist is blocked', () async {
      fx.project.write('pubspec.yaml', 'name: x');
      final shadow = await fx.create(['lib']);

      shadow.write('pubspec.yaml', 'name: y');

      final diff = await shadow.diff(
        tracked: [const Artifact.managed('pubspec.yaml')],
      );

      expect(disposition(diff, 'pubspec.yaml'), ChangeDisposition.blocked);
      expect(diff.blocked.single.path, 'pubspec.yaml');
    });

    test('a file nobody tracked is reported as untracked', () async {
      final shadow = await fx.create(['lib']);

      shadow.write('lib/stray.dart', 'x');

      final diff = await shadow.diff();

      expect(diff.changes.single.ownership, isNull);
      expect(diff.changes.single.disposition, ChangeDisposition.untracked);
      expect(diff.untracked.single.path, 'lib/stray.dart');
    });

    test('a managed file nobody recorded is a conflict', () async {
      fx.project.write('lib/flavors.dart', 'hand written');
      final shadow = await fx.create(['lib']);
      shadow.write('lib/flavors.dart', 'generated');

      final diff = await shadow.diff(
        tracked: [const Artifact.managed('lib/flavors.dart')],
      );

      expect(disposition(diff, 'lib/flavors.dart'), ChangeDisposition.conflict);
      expect(diff.hasConflicts, isTrue);
      expect(diff.changes.single.ownership, Ownership.managed);
    });

    test('a managed file untouched since the lock is overwritten', () async {
      fx.project.write('lib/flavors.dart', 'v1');
      final shadow = await fx.create(['lib']);
      shadow.write('lib/flavors.dart', 'v2');

      final diff = await shadow.diff(
        tracked: [const Artifact.managed('lib/flavors.dart')],
        recordedHashes: {'lib/flavors.dart': digestOf('v1'.codeUnits)},
      );

      expect(disposition(diff, 'lib/flavors.dart'), ChangeDisposition.apply);
    });

    test('a managed file edited since the lock is a conflict', () async {
      fx.project.write('lib/flavors.dart', 'edited by hand');
      final shadow = await fx.create(['lib']);
      shadow.write('lib/flavors.dart', 'v2');

      final diff = await shadow.diff(
        tracked: [const Artifact.managed('lib/flavors.dart')],
        recordedHashes: {'lib/flavors.dart': digestOf('v1'.codeUnits)},
      );

      expect(disposition(diff, 'lib/flavors.dart'), ChangeDisposition.conflict);
    });

    test('a new managed file is created', () async {
      final shadow = await fx.create(['lib']);
      shadow.write('lib/flavors.dart', 'v1');

      final diff = await shadow.diff(
        tracked: [const Artifact.managed('lib/flavors.dart')],
      );

      expect(disposition(diff, 'lib/flavors.dart'), ChangeDisposition.apply);
    });

    test('a scaffold the user already has is kept', () async {
      fx.project.write('lib/main.dart', 'mine');
      final shadow = await fx.create(['lib']);
      shadow.write('lib/main.dart', 'template');

      final diff = await shadow.diff(
        tracked: [const Artifact.scaffold('lib/main.dart')],
      );

      expect(disposition(diff, 'lib/main.dart'), ChangeDisposition.keep);
      expect(diff.hasConflicts, isFalse);
    });

    test('a scaffold is overwritten when asked to', () async {
      fx.project.write('lib/main.dart', 'mine');
      final shadow = await fx.create(['lib']);
      shadow.write('lib/main.dart', 'template');

      final diff = await shadow.diff(
        tracked: [const Artifact.scaffold('lib/main.dart')],
        overwriteScaffold: true,
      );

      expect(disposition(diff, 'lib/main.dart'), ChangeDisposition.apply);
    });

    test('a patched file the lock does not know yet is adopted', () async {
      fx.project.write('android/app/build.gradle', 'user');
      final shadow = await fx.create(['android/app']);
      shadow.write('android/app/build.gradle', 'user + flavors');

      final diff = await shadow.diff(
        tracked: [const Artifact.patched('android/app/build.gradle')],
      );

      expect(
        disposition(diff, 'android/app/build.gradle'),
        ChangeDisposition.apply,
      );
    });

    test('a local file is rewritten without asking', () async {
      fx.project.write('.idea/runConfigurations/a.xml', 'built');
      final shadow = await fx.create(['.idea']);
      shadow.write('.idea/runConfigurations/a.xml', 'generated');

      final diff = await shadow.diff(
        tracked: [const Artifact.local('.idea/runConfigurations/a.xml')],
        recordedHashes: {'.idea/runConfigurations/a.xml': 'sha256:other'},
      );

      expect(
        disposition(diff, '.idea/runConfigurations/a.xml'),
        ChangeDisposition.apply,
      );
    });

    test('compares the owned content through the given hasher', () async {
      // Only the first line is owned: the rest belongs to the user.
      String ownedHash(Artifact artifact, List<int> bytes) =>
          digestOf(String.fromCharCodes(bytes).split('\n').first.codeUnits);

      fx.project.write('android/app/build.gradle', 'owned v1\nuser edit');
      final shadow = await fx.create(['android/app']);
      shadow.write('android/app/build.gradle', 'owned v2\nuser edit');

      final diff = await shadow.diff(
        tracked: [const Artifact.patched('android/app/build.gradle')],
        recordedHashes: {
          'android/app/build.gradle': digestOf('owned v1'.codeUnits),
        },
        hasher: ownedHash,
      );

      expect(
        disposition(diff, 'android/app/build.gradle'),
        ChangeDisposition.apply,
      );
    });

    test('a deleted scaffold is kept', () async {
      fx.project.write('lib/main.dart', 'mine');
      final shadow = await fx.create(['lib']);
      shadow.delete('lib/main.dart');

      final diff = await shadow.diff(
        tracked: [const Artifact.scaffold('lib/main.dart')],
      );

      expect(disposition(diff, 'lib/main.dart'), ChangeDisposition.keep);
    });

    test('a deleted managed file is removed when untouched', () async {
      fx.project.write('lib/old.dart', 'v1');
      fx.project.write('lib/edited.dart', 'by hand');
      final shadow = await fx.create(['lib']);
      shadow.delete('lib/old.dart');
      shadow.delete('lib/edited.dart');

      final diff = await shadow.diff(
        tracked: [
          const Artifact.managed('lib/old.dart'),
          const Artifact.managed('lib/edited.dart'),
        ],
        recordedHashes: {
          'lib/old.dart': digestOf('v1'.codeUnits),
          'lib/edited.dart': digestOf('v1'.codeUnits),
        },
      );

      expect(disposition(diff, 'lib/old.dart'), ChangeDisposition.apply);
      expect(disposition(diff, 'lib/edited.dart'), ChangeDisposition.conflict);
    });

    test('a deleted patched file is a conflict, whatever the hash', () async {
      // A patched file owns only some regions: the rest is the user's.
      fx.project.write('android/app/build.gradle', 'user + owned');
      final shadow = await fx.create(['android/app']);
      shadow.delete('android/app/build.gradle');

      final diff = await shadow.diff(
        tracked: [const Artifact.patched('android/app/build.gradle')],
        recordedHashes: {
          'android/app/build.gradle': digestOf('user + owned'.codeUnits),
        },
      );

      expect(
        disposition(diff, 'android/app/build.gradle'),
        ChangeDisposition.conflict,
      );
    });

    group('replaced by a link in the shadow', () {
      late Directory outside;

      setUp(() {
        outside = Directory(p.join(fx.scratch.path, 'outside'))..createSync();
        File(p.join(outside.path, 'secret.txt')).writeAsStringSync('secret');
      });

      test('a file is blocked, not reported as deleted', () async {
        fx.project.write('lib/a.dart', 'a');
        final shadow = await fx.create(['lib']);
        File(p.join(shadow.root.path, 'lib', 'a.dart')).deleteSync();
        Link(
          p.join(shadow.root.path, 'lib', 'a.dart'),
        ).createSync(p.join(outside.path, 'secret.txt'));

        final diff = await shadow.diff(
          tracked: [const Artifact.local('lib/a.dart')],
        );

        expect(disposition(diff, 'lib/a.dart'), ChangeDisposition.blocked);

        await shadow.copyBack(diff);

        expect(fx.project.read('lib/a.dart'), 'a');
      });

      test('a folder blocks every file below it', () async {
        fx.project.write('lib/sub/a.dart', 'a');
        fx.project.write('lib/sub/b.dart', 'b');
        final shadow = await fx.create(['lib']);
        Directory(
          p.join(shadow.root.path, 'lib', 'sub'),
        ).deleteSync(recursive: true);
        Link(p.join(shadow.root.path, 'lib', 'sub')).createSync(outside.path);

        final diff = await shadow.diff(
          tracked: [
            const Artifact.local('lib/sub/a.dart'),
            const Artifact.local('lib/sub/b.dart'),
          ],
        );

        expect(diff.blocked.map((c) => c.path), [
          'lib/sub/a.dart',
          'lib/sub/b.dart',
        ]);

        await shadow.copyBack(diff);

        expect(fx.project.read('lib/sub/a.dart'), 'a');
        expect(fx.project.read('lib/sub/b.dart'), 'b');
      });
    }, skip: Platform.isWindows ? 'creating links needs privileges' : false);

    test('a deleted local file is removed', () async {
      fx.project.write('.idea/a.xml', 'x');
      final shadow = await fx.create(['.idea']);
      shadow.delete('.idea/a.xml');

      final diff = await shadow.diff(
        tracked: [const Artifact.local('.idea/a.xml')],
      );

      expect(disposition(diff, '.idea/a.xml'), ChangeDisposition.apply);
    });

    test('a change the real project cannot take is blocked', () async {
      final outside = Directory(p.join(fx.scratch.path, 'outside'))
        ..createSync();
      Link(fx.project.abs('ios')).createSync(outside.path);
      final shadow = await fx.create(['ios/Runner/Info.plist']);
      shadow.write('ios/Runner/Info.plist', 'x');

      final diff = await shadow.diff(
        tracked: [const Artifact.managed('ios/Runner/Info.plist')],
      );

      expect(
        disposition(diff, 'ios/Runner/Info.plist'),
        ChangeDisposition.blocked,
      );
      expect(
        File(p.join(outside.path, 'Runner', 'Info.plist')).existsSync(),
        isFalse,
      );
    }, skip: Platform.isWindows ? 'creating links needs privileges' : false);
  });

  group('render', () {
    test(
      'lists every change with its ownership and what happens to it',
      () async {
        fx.project.write('lib/a.dart', 'a');
        fx.project.write('lib/gone.dart', 'g');
        final shadow = await fx.create(['lib']);
        shadow.write('lib/a.dart', 'a2');
        shadow.write('lib/new.dart', 'n');
        shadow.delete('lib/gone.dart');
        shadow.write('lib/stray.dart', 's');

        final diff = await shadow.diff(
          tracked: [
            const Artifact.patched('lib/a.dart'),
            const Artifact.managed('lib/new.dart'),
            const Artifact.local('lib/gone.dart'),
          ],
        );

        expect(
          diff.render(),
          [
            '~ lib/a.dart (patched)',
            '- lib/gone.dart (local)',
            '+ lib/new.dart (managed)',
            '+ lib/stray.dart (untracked)',
          ].join('\n'),
        );
      },
    );

    test(
      'an existing scaffold file is skipped as user-owned, not a conflict',
      () async {
        fx.project.write('lib/main.dart', 'edited by hand');
        fx.project.write('lib/other.dart', 'v1');
        final shadow = await fx.create(['lib']);
        shadow.write('lib/main.dart', 'scaffold template');
        shadow.write('lib/other.dart', 'v2');

        final diff = await shadow.diff(
          tracked: [
            const Artifact.scaffold('lib/main.dart'),
            const Artifact.scaffold('lib/other.dart'),
          ],
          recordedHashes: {'lib/main.dart': digestOf('template'.codeUnits)},
        );

        expect(diff.hasConflicts, isFalse);
        expect(
          diff.render(),
          [
            '~ lib/main.dart (scaffold) [skipped (user-owned)]',
            '~ lib/other.dart (scaffold) [skipped (user-owned)]',
          ].join('\n'),
        );
      },
    );

    test('an overwritten scaffold file is a plain change', () async {
      fx.project.write('lib/main.dart', 'edited by hand');
      final shadow = await fx.create(['lib']);
      shadow.write('lib/main.dart', 'scaffold template');

      final diff = await shadow.diff(
        tracked: [const Artifact.scaffold('lib/main.dart')],
        overwriteScaffold: true,
      );

      expect(diff.render(), '~ lib/main.dart (scaffold)');
    });

    test('says so when there is nothing to change', () async {
      final shadow = await fx.create(['lib']);

      expect((await shadow.diff()).render(), 'No changes.');
    });
  });
}
