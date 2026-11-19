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

import 'package:flutter_flavorizr/src/entrypoint/exit_codes.dart';
import 'package:test/test.dart';

import 'cli_fixture.dart';

void main() {
  late CliFixture project;

  setUp(() => project = CliFixture());
  tearDown(() => project.dispose());

  group('a configuration with a key that is not known', () {
    setUp(() {
      // The configuration of #437: `bundle_id` for `bundleId`.
      project.write('flavorizr.yaml', '''
flavors:
  apple:
    app:
      name: "Apple"
    ios:
      bundle_id: "com.example.apple"
''');
    });

    for (final command in ['plan', 'apply', 'status', 'list']) {
      test('fails `$command` with the key, where it is and what was meant, '
          'and writes nothing', () async {
        final before = project.snapshot();

        final code = await project.run([
          command,
          if (command == 'apply') '--yes',
        ]);

        expect(code, ExitCodes.data, reason: project.logger.output);
        expect(
          project.logger.output,
          contains(
            'flavorizr.yaml:6:7: Unknown key `bundle_id` in '
            '`flavors.apple.ios`: did you mean `bundleId` instead of '
            '`bundle_id`?',
          ),
        );
        expect(project.snapshot(), before);
      });
    }
  });
}
