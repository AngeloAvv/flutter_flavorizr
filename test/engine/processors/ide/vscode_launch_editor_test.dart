/*
 * Copyright (c) 2024 Angelo Cassano
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

import 'dart:convert';

import 'package:flutter_flavorizr/src/engine/processors/ide/vscode_launch_editor.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _entry(String name, {String program = 'lib/main.dart'}) =>
    {'name': name, 'request': 'launch', 'type': 'dart', 'program': program};

/// What a `launch.json` holds, once its comments and commas are out.
List<String> _names(String source) {
  final cleaned = source
      .replaceAll(RegExp(r'//.*'), '')
      .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
      .replaceAllMapped(RegExp(r',(\s*[\]}])'), (match) => match[1]!);

  return [
    for (final item in (jsonDecode(cleaned) as Map)['configurations'] as List)
      (item as Map)['name'] as String,
  ];
}

const _template = '''
{
    // Use IntelliSense to learn about possible attributes.
    "version": "0.2.0",
    "configurations": [
        // mine
        {
            "name": "mine",
            "request": "launch",
            "type": "dart",
        },
        {
            "name": "apple Debug",
            "request": "launch",
            "type": "dart",
            "program": "old.dart"
        },
        /* theirs */
        {
            "name": "theirs",
            "type": "dart"
        }
    ]
}
''';

void main() {
  group('VsCodeLaunchEditor', () {
    test('creates a file with the entries', () {
      final source = VsCodeLaunchEditor.create([_entry('a')]);

      expect(jsonDecode(source), {
        'version': '0.2.0',
        'configurations': [_entry('a')],
      });
      expect(source, endsWith('\n'));
    });

    test('replaces an entry of a flavor and keeps what is not one', () {
      final edited = VsCodeLaunchEditor.edit(_template, [
        _entry('apple Debug'),
      ]);

      expect(edited, contains('// Use IntelliSense'));
      expect(edited, contains('// mine'));
      expect(edited, contains('/* theirs */'));
      expect(_names(edited), ['mine', 'apple Debug', 'theirs']);
      expect(edited, isNot(contains('old.dart')));
      // The entry has the layout of the others.
      expect(
        edited,
        contains(
          '        {\n'
          '            "name": "apple Debug",\n'
          '            "request": "launch",\n'
          '            "type": "dart",\n'
          '            "program": "lib/main.dart"\n'
          '        },\n',
        ),
      );
    });

    test('does not touch an entry that is already as it should be', () {
      final once = VsCodeLaunchEditor.edit(_template, [_entry('apple Debug')]);

      expect(VsCodeLaunchEditor.edit(once, [_entry('apple Debug')]), once);
    });

    test('adds the entries that are not there, after the last one', () {
      final edited = VsCodeLaunchEditor.edit(_template, [
        _entry('apple Debug'),
        _entry('banana Debug'),
        _entry('banana Release'),
      ]);

      expect(_names(edited), [
        'mine',
        'apple Debug',
        'theirs',
        'banana Debug',
        'banana Release',
      ]);
      expect(edited, contains('/* theirs */'));
      expect(
        edited,
        contains(
          '        },\n'
          '        {\n'
          '            "name": "banana Debug",',
        ),
      );
    });

    test('keeps a file with no trailing comma free of one', () {
      final edited = VsCodeLaunchEditor.edit(
        '{"configurations": [{"name": "mine"}]}',
        [_entry('a')],
      );

      expect(jsonDecode(edited)['configurations'], hasLength(2));
    });

    test('keeps the trailing comma of a file that has one', () {
      final edited = VsCodeLaunchEditor.edit(
        '{\n  "configurations": [\n    {"name": "mine"},\n  ],\n}\n',
        [_entry('a')],
      );

      expect(_names(edited), ['mine', 'a']);
      expect(edited, matches(RegExp(r'\},\s*\],', dotAll: true)));
    });

    test(
      'removes the entries of a flavor that was dropped, and nothing else',
      () {
        final edited = VsCodeLaunchEditor.edit(
          _template,
          [],
          remove: {'apple Debug'},
        );

        expect(_names(edited), ['mine', 'theirs']);
        expect(edited, contains('// mine'));
        expect(edited, contains('/* theirs */'));
        expect(edited, isNot(contains('apple')));
      },
    );

    test(
      'removes the last entry without leaving a comma that is not needed',
      () {
        final edited = VsCodeLaunchEditor.edit(
          '{\n  "configurations": [\n    {"name": "mine"},\n'
          '    {"name": "apple Debug"}\n  ]\n}\n',
          [],
          remove: {'apple Debug'},
        );

        expect(jsonDecode(edited), {
          'configurations': [
            {'name': 'mine'},
          ],
        });
      },
    );

    test('removes an entry that has spaces after its comma', () {
      final edited = VsCodeLaunchEditor.edit(
        '{\n  "configurations": [\n    {"name": "a"},   \n    {"name": "b"}\n'
        '  ]\n}\n',
        [],
        remove: {'a'},
      );

      expect(_names(edited), ['b']);
      expect(edited, isNot(contains('   \n')));
    });

    test('adds to a list that holds only a comment', () {
      final edited = VsCodeLaunchEditor.edit(
        '{"configurations": [ // nothing yet\n ]}',
        [_entry('a')],
      );

      expect(edited, contains('// nothing yet'));
      expect(_names(edited), ['a']);
    });

    test('removes every entry and still reads', () {
      final edited = VsCodeLaunchEditor.edit(
        '{\n  "configurations": [\n    {"name": "a"},\n    {"name": "b"}\n  ]\n}\n',
        [],
        remove: {'a', 'b'},
      );

      expect(jsonDecode(edited), {'configurations': <Object?>[]});
    });

    test('fills a list that has no entry', () {
      final edited = VsCodeLaunchEditor.edit(
        '{\n  "version": "0.2.0",\n  "configurations": []\n}\n',
        [_entry('a')],
      );

      expect(_names(edited), ['a']);
    });

    test('keeps one of the entries that have the same name', () {
      final edited = VsCodeLaunchEditor.edit(
        '{"configurations": [{"name": "a"}, {"name": "a"}]}',
        [_entry('a')],
      );

      expect(_names(edited), ['a']);
    });

    test('leaves the entries without a name alone', () {
      final edited = VsCodeLaunchEditor.edit(
        '{"configurations": [{"type": "dart"}, "text", 4]}',
        [_entry('a')],
      );

      expect(jsonDecode(edited)['configurations'], [
        {'type': 'dart'},
        'text',
        4,
        _entry('a'),
      ]);
    });

    test('adds `configurations` to a file that has none', () {
      expect(
        jsonDecode(
          VsCodeLaunchEditor.edit('{"version": "0.2.0"}', [_entry('a')]),
        ),
        {
          'version': '0.2.0',
          'configurations': [_entry('a')],
        },
      );
      expect(jsonDecode(VsCodeLaunchEditor.edit('{ }', [_entry('a')])), {
        'configurations': [_entry('a')],
      });
    });

    test('reads a file with a byte order mark and a comment at the end', () {
      final edited = VsCodeLaunchEditor.edit(
        '﻿{"configurations": []} // the end\n',
        [_entry('a')],
      );

      expect(edited, contains('// the end'));
    });

    test('keeps strings that look like comments', () {
      final edited = VsCodeLaunchEditor.edit(
        '{"configurations": [{"name": "mine", "program": "http://x/*y*/"}]}',
        [_entry('a')],
      );

      expect(edited, contains('"http://x/*y*/"'));
    });

    for (final (source, reason) in [
      ('', 'nothing'),
      ('[]', 'a list'),
      ('{"configurations": {}}', '`configurations` that is not a list'),
      ('{"configurations": [}', 'a list that is not closed'),
      ('{"configurations": [{"name": "a"} {"name": "b"}]}', 'no comma'),
      ('{"a": }', 'a key without a value'),
      ('{"a": "b" /* ', 'a comment that is not closed'),
      ('{"a": "b', 'a string that is not closed'),
      ('{a: 1}', 'a key without quotes'),
      ('{"a": nope}', 'a value that is not one'),
      ('{} {}', 'something after the document'),
      ('{"a": 1 "b": 2}', 'a member that follows another with no comma'),
      ('{"a" 1}', 'a key with no colon'),
    ]) {
      test('refuses $reason', () {
        expect(
          () => VsCodeLaunchEditor.edit(source, [_entry('a')]),
          throwsFormatException,
        );
      });
    }
  });
}
