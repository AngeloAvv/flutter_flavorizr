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
import 'package:flutter_flavorizr/src/engine/conflict/conflict_content.dart';
import 'package:flutter_flavorizr/src/engine/conflict/conflict_policy.dart';
import 'package:flutter_flavorizr/src/engine/conflict/conflict_resolver.dart';
import 'package:flutter_flavorizr/src/engine/shadow/file_digest.dart';
import 'package:flutter_flavorizr/src/engine/shadow/shadow_workspace.dart';
import 'package:flutter_flavorizr/src/engine/shadow/workspace_diff.dart';
import 'package:flutter_flavorizr/src/exception/unapproved_conflicts_exception.dart';
import 'package:flutter_test/flutter_test.dart';

import '../shadow/shadow_fixture.dart';
import 'conflict_fakes.dart';

/// Resolution against a real shadow workspace and a real copy-back: the point
/// is what ends up on disk.
void main() {
  late ShadowFixture fx;
  late ShadowWorkspace shadow;
  late WorkspaceDiff diff;

  setUp(() => fx = ShadowFixture());
  tearDown(() => fx.dispose());

  /// A project where `lib/flavors.dart` (managed) was edited by hand since the
  /// lock, `lib/app.dart` (managed) is up to date, and the run rewrites both,
  /// deletes `lib/old.dart` (managed, edited by hand) and creates
  /// `lib/new.dart`.
  Future<void> prepare() async {
    fx.project.write('lib/flavors.dart', 'edited by hand');
    fx.project.write('lib/app.dart', 'app v1');
    fx.project.write('lib/old.dart', 'old, edited by hand');
    shadow = await fx.create(['lib']);
    shadow.write('lib/flavors.dart', 'flavors v2');
    shadow.write('lib/app.dart', 'app v2');
    shadow.delete('lib/old.dart');
    shadow.write('lib/new.dart', 'new');

    diff = await shadow.diff(
      tracked: [
        const Artifact.managed('lib/flavors.dart'),
        const Artifact.managed('lib/app.dart'),
        const Artifact.managed('lib/old.dart'),
        const Artifact.managed('lib/new.dart'),
      ],
      recordedHashes: {
        'lib/flavors.dart': digestOf('flavors v1'.codeUnits),
        'lib/app.dart': digestOf('app v1'.codeUnits),
        'lib/old.dart': digestOf('old'.codeUnits),
      },
    );
  }

  ConflictResolver resolver({
    ConflictPolicy? policy,
    List<String?> answers = const [],
  }) => ConflictResolver(
    terminal: FakeTerminal(isInteractive: answers.isNotEmpty, answers: answers),
    content: ShadowConflictContent(shadow),
    policy: policy,
  );

  test('the setup has the conflicts the tests rely on', () async {
    await prepare();

    expect(diff.conflicts.map((c) => c.path), [
      'lib/flavors.dart',
      'lib/old.dart',
    ]);
  });

  test('overwrite replaces and deletes the conflicting files', () async {
    await prepare();

    final resolution = await resolver(
      policy: ConflictPolicy.overwrite,
    ).resolve(diff);

    await shadow.copyBack(
      resolution.applyTo(diff),
      approvedConflicts: resolution.approved,
    );

    expect(fx.project.read('lib/flavors.dart'), 'flavors v2');
    expect(fx.project.exists('lib/old.dart'), isFalse);
    expect(fx.project.read('lib/app.dart'), 'app v2');
    expect(fx.project.read('lib/new.dart'), 'new');
  });

  test(
    'keep leaves the conflicting files untouched and writes the rest',
    () async {
      await prepare();

      final resolution = await resolver(
        policy: ConflictPolicy.keep,
      ).resolve(diff);

      final result = await shadow.copyBack(
        resolution.applyTo(diff),
        approvedConflicts: resolution.approved,
      );

      expect(fx.project.read('lib/flavors.dart'), 'edited by hand');
      expect(fx.project.read('lib/old.dart'), 'old, edited by hand');
      expect(fx.project.read('lib/app.dart'), 'app v2');
      expect(fx.project.read('lib/new.dart'), 'new');
      expect(result.applied.map((c) => c.path), [
        'lib/app.dart',
        'lib/new.dart',
      ]);
    },
  );

  test(
    'copy-back refuses kept conflicts unless the diff goes through applyTo',
    () async {
      await prepare();

      final resolution = await resolver(
        policy: ConflictPolicy.keep,
      ).resolve(diff);

      await expectLater(
        shadow.copyBack(diff, approvedConflicts: resolution.approved),
        throwsA(isA<UnapprovedConflictsException>()),
      );
      expect(fx.project.read('lib/flavors.dart'), 'edited by hand');
    },
  );

  test('a mixed interactive answer is honoured file by file', () async {
    await prepare();

    final resolution = await resolver(answers: ['o', 'k']).resolve(diff);

    await shadow.copyBack(
      resolution.applyTo(diff),
      approvedConflicts: resolution.approved,
    );

    expect(fx.project.read('lib/flavors.dart'), 'flavors v2');
    expect(fx.project.read('lib/old.dart'), 'old, edited by hand');
  });

  test('applyTo only changes the kept conflicts', () async {
    await prepare();

    final resolution = ConflictResolution(
      approved: ['lib/flavors.dart'],
      kept: ['lib/old.dart'],
    );
    final result = resolution.applyTo(diff);

    expect(
      {for (final c in result.changes) c.path: c.disposition},
      {
        'lib/app.dart': ChangeDisposition.apply,
        'lib/flavors.dart': ChangeDisposition.conflict,
        'lib/new.dart': ChangeDisposition.apply,
        'lib/old.dart': ChangeDisposition.keep,
      },
    );
    expect(diff.conflicts, hasLength(2), reason: 'the input is not modified');
  });

  group('ShadowConflictContent', () {
    test('reads the project file and the workspace file', () async {
      await prepare();
      final content = ShadowConflictContent(shadow);

      expect(
        await content.readCurrent('lib/flavors.dart'),
        'edited by hand'.codeUnits,
      );
      expect(
        await content.readDesired('lib/flavors.dart'),
        'flavors v2'.codeUnits,
      );
    });

    test('a deleted file has no desired content', () async {
      await prepare();

      expect(
        await ShadowConflictContent(shadow).readDesired('lib/old.dart'),
        isNull,
      );
    });

    test(
      'a file that does not exist in the project has no current content',
      () async {
        await prepare();

        expect(
          await ShadowConflictContent(shadow).readCurrent('lib/new.dart'),
          isNull,
        );
      },
    );

    test('never follows a link', () async {
      final outside = Directory.systemTemp.createTempSync('flavorizr_outside_');
      addTearDown(() => outside.deleteSync(recursive: true));
      File('${outside.path}/secret.txt').writeAsStringSync('secret');
      fx.project.write('lib/a.dart', 'a');
      shadow = await fx.create(['lib']);
      Link(
        '${shadow.root.path}/lib/link.txt',
      ).createSync('${outside.path}/secret.txt');
      Link(
        '${fx.project.root.path}/lib/link.txt',
      ).createSync('${outside.path}/secret.txt');
      final content = ShadowConflictContent(shadow);

      expect(await content.readDesired('lib/link.txt'), isNull);
      expect(await content.readCurrent('lib/link.txt'), isNull);
    });

    test('is a ConflictContent', () async {
      await prepare();

      expect(ShadowConflictContent(shadow), isA<ConflictContent>());
    });
  });
}
