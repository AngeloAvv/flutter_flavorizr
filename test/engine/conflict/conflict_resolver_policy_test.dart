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

import 'package:flutter_flavorizr/src/engine/conflict/conflict_policy.dart';
import 'package:flutter_flavorizr/src/engine/conflict/conflict_resolver.dart';
import 'package:flutter_flavorizr/src/engine/shadow/workspace_diff.dart';
import 'package:flutter_flavorizr/src/exception/unresolved_conflicts_exception.dart';
import 'package:flutter_test/flutter_test.dart';

import 'conflict_fakes.dart';

void main() {
  ConflictResolver resolver({
    required FakeTerminal terminal,
    ConflictPolicy? policy,
    bool yes = false,
  }) => ConflictResolver(
    terminal: terminal,
    content: FakeContent(),
    policy: policy,
    yes: yes,
  );

  final diff = WorkspaceDiff([
    conflict('lib/a.dart'),
    conflict('lib/b.dart', kind: ChangeKind.deleted),
    applying('lib/c.dart'),
  ]);

  group('without conflicts', () {
    test('nothing is asked, approved or kept', () async {
      final terminal = FakeTerminal();
      final resolution = await resolver(
        terminal: terminal,
      ).resolve(WorkspaceDiff([applying('lib/c.dart')]));

      expect(resolution.approved, isEmpty);
      expect(resolution.kept, isEmpty);
      expect(terminal.prompts, isEmpty);
      expect(terminal.output.toString(), isEmpty);
    });

    test('a policy has nothing to decide', () async {
      final resolution = await resolver(
        terminal: FakeTerminal(isInteractive: false),
        policy: ConflictPolicy.keep,
      ).resolve(WorkspaceDiff(const []));

      expect(resolution.approved, isEmpty);
      expect(resolution.kept, isEmpty);
    });
  });

  group('on a non-TTY', () {
    final terminal = FakeTerminal(isInteractive: false);

    test('fails listing every conflict, without a policy', () async {
      await expectLater(
        resolver(terminal: terminal).resolve(diff),
        throwsA(
          isA<UnresolvedConflictsException>().having((e) => e.paths, 'paths', [
            'lib/a.dart',
            'lib/b.dart',
          ]),
        ),
      );
      expect(terminal.prompts, isEmpty);
    });

    test('the failure cannot carry control sequences from a path', () {
      expect(
        UnresolvedConflictsException(['lib/\x1B[2Ja.dart']).toString(),
        isNot(contains('\x1B')),
      );
    });

    test('the failure shows a path with a newline as one entry', () {
      final message = UnresolvedConflictsException([
        'lib/a.dart\n  - lib/b.dart',
      ]).toString();

      expect(message, contains('  - lib/a.dart␊  - lib/b.dart\n'));
      expect('\n  - '.allMatches(message), hasLength(1));
    });

    test('the failure tells how to resolve', () {
      final message = UnresolvedConflictsException(
        diff.conflicts.map((change) => change.path),
      ).toString();

      expect(message, contains('  - lib/a.dart'));
      expect(message, contains('  - lib/b.dart'));
      expect(message, contains('--on-conflict=keep|overwrite'));
    });

    test('--on-conflict=overwrite approves every conflict', () async {
      final resolution = await resolver(
        terminal: terminal,
        policy: ConflictPolicy.overwrite,
      ).resolve(diff);

      expect(resolution.approved, {'lib/a.dart', 'lib/b.dart'});
      expect(resolution.kept, isEmpty);
    });

    test(
      '--on-conflict=keep approves nothing and keeps every conflict',
      () async {
        final resolution = await resolver(
          terminal: terminal,
          policy: ConflictPolicy.keep,
        ).resolve(diff);

        expect(resolution.approved, isEmpty);
        expect(resolution.kept, {'lib/a.dart', 'lib/b.dart'});
      },
    );
  });

  group('with --yes on a TTY', () {
    test('fails listing the conflicts, without asking', () async {
      final terminal = FakeTerminal();

      await expectLater(
        resolver(terminal: terminal, yes: true).resolve(diff),
        throwsA(isA<UnresolvedConflictsException>()),
      );
      expect(terminal.prompts, isEmpty);
    });

    test('--on-conflict=overwrite approves, without asking', () async {
      final terminal = FakeTerminal();
      final resolution = await resolver(
        terminal: terminal,
        yes: true,
        policy: ConflictPolicy.overwrite,
      ).resolve(diff);

      expect(resolution.approved, {'lib/a.dart', 'lib/b.dart'});
      expect(terminal.prompts, isEmpty);
    });

    test('--on-conflict=keep keeps, without asking', () async {
      final terminal = FakeTerminal();
      final resolution = await resolver(
        terminal: terminal,
        yes: true,
        policy: ConflictPolicy.keep,
      ).resolve(diff);

      expect(resolution.kept, {'lib/a.dart', 'lib/b.dart'});
      expect(terminal.prompts, isEmpty);
    });
  });

  group('with a policy on a TTY', () {
    test('overwrite approves, without asking', () async {
      final terminal = FakeTerminal();
      final resolution = await resolver(
        terminal: terminal,
        policy: ConflictPolicy.overwrite,
      ).resolve(diff);

      expect(resolution.approved, {'lib/a.dart', 'lib/b.dart'});
      expect(terminal.prompts, isEmpty);
    });

    test('keep keeps, without asking', () async {
      final terminal = FakeTerminal();
      final resolution = await resolver(
        terminal: terminal,
        policy: ConflictPolicy.keep,
      ).resolve(diff);

      expect(resolution.kept, {'lib/a.dart', 'lib/b.dart'});
      expect(terminal.prompts, isEmpty);
    });
  });
}
