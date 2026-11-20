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
import 'dart:io';

import 'package:flutter_flavorizr/src/entrypoint/exit_codes.dart';
import 'package:test/test.dart';

import 'cli_fixture.dart';

const _idea = '.idea/runConfigurations';
const _launch = '.vscode/launch.json';

String _config(Iterable<String> flavors, {String ide = 'idea'}) =>
    '${CliFixture.config(flavors)}ide:\n  - $ide\n';

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

void main() {
  late CliFixture project;

  setUp(() => project = CliFixture());
  tearDown(() => project.dispose());

  group('ide:config on the engine', () {
    test('writes the run configurations of IntelliJ for each flavor', () async {
      project.write('flavorizr.yaml', _config(['apple', 'banana']));

      final code = await project.run(['apply', '--yes']);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.read('$_idea/apple.xml'), contains('name="apple"'));
      expect(project.read('$_idea/banana.xml'), contains('value="banana"'));
    });

    test('keeps no file of the IDE in the lock, so a fresh clone is in sync, '
        'and the files come back', () async {
      project.write('flavorizr.yaml', _config(['apple']));
      await project.run(['apply', '--yes']);

      expect(project.read('flavorizr.lock'), isNot(contains('.idea')));

      // A fresh clone has no `.idea/`: git ignores it.
      Directory(project.abs(_idea)).deleteSync(recursive: true);

      expect(await project.run(['status']), ExitCodes.ok);
      expect(project.exists('$_idea/apple.xml'), isFalse);

      await project.run(['apply', '--yes']);

      expect(project.exists('$_idea/apple.xml'), isTrue);
    });

    test('regenerates a run configuration that was edited, with no conflict, '
        'and removes the one of a flavor that was dropped', () async {
      project.write('flavorizr.yaml', _config(['apple', 'banana']));
      await project.run(['apply', '--yes']);
      project.write('$_idea/apple.xml', 'edited by the IDE');
      project.write('$_idea/mine.xml', 'a run configuration of the user');
      project.write('flavorizr.yaml', _config(['apple']));

      final code = await project.run(['apply', '--yes']);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.read('$_idea/apple.xml'), contains('buildFlavor'));
      expect(project.exists('$_idea/banana.xml'), isFalse);
      expect(
        project.read('$_idea/mine.xml'),
        'a run configuration of the user',
      );
    });

    group('launch.json', () {
      const template = '''
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
    ]
}
''';

      test('is created when there is none', () async {
        project.write('flavorizr.yaml', _config(['apple'], ide: 'vscode'));

        final code = await project.run(['apply', '--yes']);

        expect(code, ExitCodes.ok, reason: project.logger.output);
        expect(_names(project.read(_launch)), [
          'apple Debug',
          'apple Profile',
          'apple Release',
        ]);
        expect(project.read('flavorizr.lock'), isNot(contains('.vscode')));
      });

      test('keeps its comments and the entries of the user', () async {
        project.write('flavorizr.yaml', _config(['apple'], ide: 'vscode'));
        project.write(_launch, template);

        final code = await project.run(['apply', '--yes']);
        final launch = project.read(_launch);

        expect(code, ExitCodes.ok, reason: project.logger.output);
        expect(launch, contains('// Use IntelliSense'));
        expect(launch, contains('// mine'));
        expect(_names(launch), [
          'mine',
          'apple Debug',
          'apple Profile',
          'apple Release',
        ]);

        // A second run changes nothing.
        final before = project.snapshot();

        await project.run(['apply', '--yes']);

        expect(project.snapshot(), before);
      });

      test(
        'loses the entries of a flavor that was dropped, and only those',
        () async {
          project.write(
            'flavorizr.yaml',
            _config(['apple', 'banana'], ide: 'vscode'),
          );
          project.write(_launch, template);
          await project.run(['apply', '--yes']);
          project.write('flavorizr.yaml', _config(['apple'], ide: 'vscode'));

          final code = await project.run(['apply', '--yes']);
          final launch = project.read(_launch);

          expect(code, ExitCodes.ok, reason: project.logger.output);
          expect(launch, contains('// mine'));
          expect(_names(launch), [
            'mine',
            'apple Debug',
            'apple Profile',
            'apple Release',
          ]);
        },
      );

      test(
        'that cannot be read is left alone, and the entries are printed',
        () async {
          project.write('flavorizr.yaml', _config(['apple'], ide: 'vscode'));
          project.write(_launch, '{ "configurations": [ oops ] }');

          final code = await project.run(['apply', '--yes']);

          expect(code, ExitCodes.ok, reason: project.logger.output);
          expect(project.read(_launch), '{ "configurations": [ oops ] }');
          expect(project.logger.warnings.join(), contains('apple Debug'));
          expect(project.logger.warnings.join(), contains('cannot be read'));
        },
      );
    });

    test('does nothing without `ide`', () async {
      final code = await project.run(['apply', '--yes']);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.exists('.idea'), isFalse);
      expect(project.exists('.vscode'), isFalse);
    });
  });
}
