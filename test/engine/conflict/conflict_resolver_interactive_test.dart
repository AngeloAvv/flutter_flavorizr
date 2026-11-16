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

import 'package:flutter_flavorizr/src/engine/conflict/conflict_content.dart';
import 'package:flutter_flavorizr/src/engine/conflict/conflict_resolver.dart';
import 'package:flutter_flavorizr/src/engine/shadow/workspace_diff.dart';
import 'package:flutter_flavorizr/src/exception/unresolved_conflicts_exception.dart';
import 'package:flutter_test/flutter_test.dart';

import 'conflict_fakes.dart';

void main() {
  final diff = WorkspaceDiff([
    conflict('lib/c.dart'),
    conflict('lib/a.dart'),
    applying('lib/z.dart'),
    conflict('lib/b.dart', kind: ChangeKind.deleted),
  ]);

  Future<ConflictResolution> resolveWith(
    FakeTerminal terminal, {
    ConflictContent? content,
    WorkspaceDiff? of,
  }) => ConflictResolver(
    terminal: terminal,
    content: content ?? FakeContent(),
  ).resolve(of ?? diff);

  group('on a TTY without a policy', () {
    test(
      'asks for each conflict, in path order, and only for conflicts',
      () async {
        final terminal = FakeTerminal(answers: ['o', 'o', 'o']);

        await resolveWith(terminal);

        expect(terminal.prompts, hasLength(3));
        expect(
          terminal.output.toString(),
          stringContainsInOrder(['lib/a.dart', 'lib/b.dart', 'lib/c.dart']),
        );
        expect(terminal.output.toString(), isNot(contains('lib/z.dart')));
      },
    );

    test('the prompt offers the four choices', () async {
      final terminal = FakeTerminal(answers: ['k', 'k', 'k']);

      await resolveWith(terminal);

      expect(
        terminal.prompts.first,
        contains('[o]verwrite / [k]eep / [d]iff / overwrite [a]ll'),
      );
    });

    test('overwrite approves the file', () async {
      final resolution = await resolveWith(
        FakeTerminal(answers: ['o', 'o', 'o']),
      );

      expect(resolution.approved, {'lib/a.dart', 'lib/b.dart', 'lib/c.dart'});
      expect(resolution.kept, isEmpty);
    });

    test('keep keeps the file', () async {
      final resolution = await resolveWith(
        FakeTerminal(answers: ['k', 'k', 'k']),
      );

      expect(resolution.approved, isEmpty);
      expect(resolution.kept, {'lib/a.dart', 'lib/b.dart', 'lib/c.dart'});
    });

    test('each file gets its own answer, deletions included', () async {
      final resolution = await resolveWith(
        FakeTerminal(answers: ['o', 'k', 'o']),
      );

      expect(resolution.approved, {'lib/a.dart', 'lib/c.dart'});
      expect(resolution.kept, {'lib/b.dart'});
    });

    test(
      'overwrite all approves this file and the ones left, once confirmed',
      () async {
        final terminal = FakeTerminal(answers: ['k', 'a', 'y']);
        final resolution = await resolveWith(terminal);

        expect(resolution.kept, {'lib/a.dart'});
        expect(resolution.approved, {'lib/b.dart', 'lib/c.dart'});
        expect(terminal.prompts, hasLength(3));
        expect(terminal.prompts.last, contains('2 file(s)'));
      },
    );

    test('overwrite all lists what it covers, deletions marked', () async {
      final terminal = FakeTerminal(answers: ['a', 'yes']);

      await resolveWith(terminal);

      expect(
        terminal.output.toString(),
        stringContainsInOrder([
          'This overwrites all remaining files:',
          '  - lib/a.dart',
          '  - lib/b.dart (delete)',
          '  - lib/c.dart',
        ]),
      );
    });

    for (final refusal in ['', 'n', 'no', 'yep', ' ']) {
      test(
        'overwrite all not confirmed ("$refusal") asks again for the file',
        () async {
          final terminal = FakeTerminal(answers: ['a', refusal, 'k', 'k', 'k']);
          final resolution = await resolveWith(terminal);

          expect(resolution.approved, isEmpty);
          expect(resolution.kept, hasLength(3));
          expect(terminal.output.toString(), contains('Not confirmed.'));
        },
      );
    }

    test(
      'the input ending while confirming fails, approving nothing',
      () async {
        final terminal = FakeTerminal(answers: ['a', null]);

        await expectLater(
          resolveWith(terminal),
          throwsA(isA<UnresolvedConflictsException>()),
        );
      },
    );

    test(
      'answers are case insensitive, trimmed and may be spelled out',
      () async {
        final resolution = await resolveWith(
          FakeTerminal(answers: ['  OVERWRITE ', 'Keep', 'K']),
        );

        expect(resolution.approved, {'lib/a.dart'});
        expect(resolution.kept, {'lib/b.dart', 'lib/c.dart'});
      },
    );

    test('an unknown answer asks again for the same file', () async {
      final terminal = FakeTerminal(answers: ['', 'maybe', 'o', 'o', 'o']);
      final resolution = await resolveWith(terminal);

      expect(terminal.prompts, hasLength(5));
      expect(terminal.output.toString(), contains('Please answer'));
      expect(resolution.approved, hasLength(3));
    });

    group('diff', () {
      final content = FakeContent(
        current: {'lib/a.dart': 'mine\nshared\n', 'lib/b.dart': 'gone\n'},
        desired: {'lib/a.dart': 'theirs\nshared\n'},
      );
      final two = WorkspaceDiff([
        conflict('lib/a.dart'),
        conflict('lib/b.dart', kind: ChangeKind.deleted),
      ]);

      test('shows the unified diff and asks again for the same file', () async {
        final terminal = FakeTerminal(answers: ['d', 'o', 'k']);
        final resolution = await resolveWith(
          terminal,
          content: content,
          of: two,
        );

        expect(terminal.prompts, hasLength(3));
        expect(
          terminal.output.toString(),
          stringContainsInOrder([
            '--- a/lib/a.dart',
            '+++ b/lib/a.dart',
            '-mine',
            '+theirs',
            ' shared',
          ]),
        );
        expect(resolution.approved, {'lib/a.dart'});
        expect(resolution.kept, {'lib/b.dart'});
      });

      test('explains which side is which', () async {
        final terminal = FakeTerminal(answers: ['d', 'k', 'k']);

        await resolveWith(terminal, content: content, of: two);

        expect(terminal.output.toString(), contains('- your file'));
        expect(terminal.output.toString(), contains('+ what flavorizr'));
      });

      test('can be asked more than once', () async {
        final terminal = FakeTerminal(answers: ['d', 'd', 'k', 'k']);

        await resolveWith(terminal, content: content, of: two);

        expect('+theirs'.allMatches(terminal.output.toString()), hasLength(2));
      });

      test('a deletion shows the whole file as removed', () async {
        final terminal = FakeTerminal(answers: ['k', 'd', 'k']);

        await resolveWith(terminal, content: content, of: two);

        expect(terminal.output.toString(), contains('-gone'));
      });

      test('is coloured on a terminal that supports colours', () async {
        final terminal = FakeTerminal(
          supportsColor: true,
          answers: ['d', 'k', 'k'],
        );

        await resolveWith(terminal, content: content, of: two);

        expect(terminal.output.toString(), contains('\x1B[31m-mine\x1B[0m'));
        expect(terminal.output.toString(), contains('\x1B[32m+theirs\x1B[0m'));
      });

      test('is plain without colours', () async {
        final terminal = FakeTerminal(answers: ['d', 'k', 'k']);

        await resolveWith(terminal, content: content, of: two);

        expect(terminal.output.toString(), isNot(contains('\x1B')));
      });

      test('says so when the files are binary', () async {
        final terminal = FakeTerminal(answers: ['d', 'k']);

        await resolveWith(
          terminal,
          content: _BinaryContent(),
          of: WorkspaceDiff([conflict('img.png')]),
        );

        expect(terminal.output.toString(), contains('Binary files differ'));
      });

      test('says so when a file cannot be read as a regular file', () async {
        final terminal = FakeTerminal(answers: ['d', 'k']);

        await resolveWith(
          terminal,
          content: FakeContent(desired: {'lib/a.dart': 'new\n'}),
          of: WorkspaceDiff([conflict('lib/a.dart')]),
        );

        expect(terminal.output.toString(), contains('Cannot show the diff'));
        expect(terminal.output.toString(), isNot(contains('+new')));
      });

      test('never sends control sequences from a path or a file', () async {
        final terminal = FakeTerminal(
          supportsColor: false,
          answers: ['d', 'a', 'n', 'k'],
        );

        await resolveWith(
          terminal,
          content: FakeContent(
            current: {'lib/\x1B[2Ja.dart': 'a\x1B[31m\rb\n'},
            desired: {'lib/\x1B[2Ja.dart': 'c\u009B\n'},
          ),
          of: WorkspaceDiff([conflict('lib/\x1B[2Ja.dart')]),
        );

        expect(terminal.output.toString(), isNot(contains('\x1B')));
        expect(terminal.output.toString(), isNot(contains('\r')));
        expect(terminal.output.toString(), isNot(contains('\u009B')));
        expect(terminal.output.toString(), contains('lib/␛[2Ja.dart'));
      });

      test('says so when there is nothing to show', () async {
        final terminal = FakeTerminal(answers: ['d', 'k']);

        await resolveWith(
          terminal,
          content: FakeContent(
            current: {'lib/a.dart': 'same\n'},
            desired: {'lib/a.dart': 'same\n'},
          ),
          of: WorkspaceDiff([conflict('lib/a.dart')]),
        );

        expect(terminal.output.toString(), contains('No textual differences'));
      });
    });

    test('the input ending fails listing the files still unresolved', () async {
      final terminal = FakeTerminal(answers: ['o', null]);

      await expectLater(
        resolveWith(terminal),
        throwsA(
          isA<UnresolvedConflictsException>().having((e) => e.paths, 'paths', [
            'lib/b.dart',
            'lib/c.dart',
          ]),
        ),
      );
    });
  });
}

/// Content that is not text.
class _BinaryContent implements ConflictContent {
  @override
  Future<List<int>?> readCurrent(String path) async => [0xff, 0xfe, 0x00];

  @override
  Future<List<int>?> readDesired(String path) async => [0xff, 0xfd, 0x01];
}
