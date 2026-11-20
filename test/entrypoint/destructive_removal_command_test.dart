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

import 'package:flutter_flavorizr/src/entrypoint/exit_codes.dart';
import 'package:test/test.dart';

import 'cli_fixture.dart';

void main() {
  late CliFixture project;

  setUp(() async {
    project = CliFixture();
    await project.run(['apply', '--yes', ...engineTargets]);
  });
  tearDown(() => project.dispose());

  for (final command in ['plan', 'apply']) {
    group(command, () {
      List<String> args([List<String> extra = const []]) => [
        command,
        if (command == 'apply') '--yes',
        ...extra,
        ...engineTargets,
      ];

      test('keeps working when flavors are removed down to one', () async {
        project.write('flavorizr.yaml', CliFixture.config(['apple']));

        final code = await project.run(args());

        expect(code, ExitCodes.ok, reason: project.logger.output);
      });

      test('refuses to remove the last flavor, and writes nothing', () async {
        project.write('flavorizr.yaml', 'flavors: {}\n');
        final before = project.snapshot();

        final code = await project.run(args());

        expect(code, ExitCodes.data, reason: project.logger.output);
        expect(project.snapshot(), before);
        expect(project.questions, isEmpty);
        expect(
          project.logger.errors.join('\n'),
          allOf(
            contains('apple, banana'),
            contains('android:label'),
            contains('out of scope'),
          ),
        );
      });

      test('refuses to drop a flavorized platform, naming it', () async {
        project.write(
          'flavorizr.yaml',
          'flavors:\n  apple:\n    app:\n      name: apple\n',
        );
        final before = project.snapshot();

        final code = await project.run(args());

        expect(code, ExitCodes.data, reason: project.logger.output);
        expect(project.snapshot(), before);
        expect(
          project.logger.errors.join('\n'),
          allOf(
            contains('android'),
            contains('android/app/flavorizr.gradle'),
            contains('out of scope'),
          ),
        );
      });

      test('refuses even when the targets leave the platform out', () async {
        project.write('flavorizr.yaml', 'flavors: {}\n');

        final code = await project.run([
          command,
          if (command == 'apply') '--yes',
          'huawei:agconnect',
        ]);

        expect(code, ExitCodes.data, reason: project.logger.output);
      });

      test('does not refuse a project that was never applied', () async {
        project.dispose();
        project = CliFixture(android: false);
        project.write(
          'flavorizr.yaml',
          'flavors:\n  apple:\n    app:\n      name: apple\n',
        );

        final code = await project.run(args());

        expect(code, ExitCodes.ok, reason: project.logger.output);
      });
    });
  }
}
