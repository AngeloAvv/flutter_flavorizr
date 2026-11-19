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

import 'package:flutter_flavorizr/src/engine/ownership.dart';
import 'package:flutter_flavorizr/src/engine/shadow/workspace_diff.dart';
import 'package:flutter_flavorizr/src/entrypoint/output/style.dart';
import 'package:test/test.dart';

FileChange change(
  ChangeKind kind, {
  ChangeDisposition disposition = ChangeDisposition.apply,
}) => FileChange(
  path: 'android/app/a.txt',
  kind: kind,
  ownership: Ownership.managed,
  disposition: disposition,
  before: null,
  after: null,
);

void main() {
  const color = Style(color: true);
  const none = Style.none();

  test('says nothing when there is no colour', () {
    expect(none.green('a'), 'a');
    expect(none.bold('a'), 'a');
    expect(
      none.change(change(ChangeKind.added)),
      '+ android/app/a.txt (managed)',
    );
    expect(
      none.diff('+ a (added)\n- b (removed)'),
      '+ a (added)\n- b (removed)',
    );
  });

  test('wraps the text in an SGR code and resets it', () {
    expect(color.green('a'), '\x1B[32ma\x1B[39m');
    expect(color.red('a'), '\x1B[31ma\x1B[39m');
    expect(color.yellow('a'), '\x1B[33ma\x1B[39m');
    expect(color.bold('a'), '\x1B[1ma\x1B[22m');
    expect(color.dim('a'), '\x1B[2ma\x1B[22m');
  });

  group('a change', () {
    test('is green when added, yellow when modified, red when deleted', () {
      expect(color.change(change(ChangeKind.added)), startsWith('\x1B[32m'));
      expect(color.change(change(ChangeKind.modified)), startsWith('\x1B[33m'));
      expect(color.change(change(ChangeKind.deleted)), startsWith('\x1B[31m'));
    });

    test('is red when it is a conflict, whatever it is', () {
      expect(
        color.change(
          change(ChangeKind.added, disposition: ChangeDisposition.conflict),
        ),
        startsWith('\x1B[31m'),
      );
    });

    test('keeps the words of its description', () {
      expect(
        color.change(change(ChangeKind.modified)),
        contains('~ android/app/a.txt (managed)'),
      );
    });
  });

  group('a diff', () {
    test('colours the lines that start with + ~ or -', () {
      expect(
        color.diff('- a (removed)\n+ b (added)\n~ c (changed)'),
        '\x1B[31m- a (removed)\x1B[39m\n'
        '\x1B[32m+ b (added)\x1B[39m\n'
        '\x1B[33m~ c (changed)\x1B[39m',
      );
    });

    test('leaves the other lines as they are', () {
      expect(color.diff('No flavor changes.'), 'No flavor changes.');
      expect(color.diff('  - indented'), '  - indented');
    });
  });
}
