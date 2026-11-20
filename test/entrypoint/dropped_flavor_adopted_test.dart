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

import 'adopt_fixture.dart';
import 'cli_fixture.dart';

const _iosScheme =
    'ios/Runner.xcodeproj/xcshareddata/xcschemes/banana.xcscheme';
const _macosScheme =
    'macos/Runner.xcodeproj/xcshareddata/xcschemes/banana.xcscheme';
const _iosCopy = 'ios/Runner/banana/GoogleService-Info.plist';
const _macosCopy = 'macos/Runner/banana/GoogleService-Info.plist';
const _androidCopy = 'android/app/src/banana/google-services.json';

/// What 3.x does with what 2.x made for a flavor that is dropped from the
/// configuration of a project that was adopted: nothing in the lock says that
/// flavorizr made the schemes and the copies, so they are left to the user, and
/// the plan says so.
void main() {
  late CliFixture project;

  /// The configuration without `banana`.
  void dropBanana() {
    final yaml = project
        .read('flavorizr.yaml')
        .replaceFirst(RegExp(r'  banana:.*?(?=\nide:)', dotAll: true), '');

    expect(yaml, isNot(contains('banana')));
    project.write('flavorizr.yaml', yaml);
  }

  setUp(() => project = project2x());
  tearDown(() => project.dispose());

  test('leaves the schemes 2.x made, and says so in the plan', () async {
    expect(await project.run(['adopt']), ExitCodes.ok);
    dropBanana();

    final changes = await planned(project);

    expect(changes.keys, isNot(contains(_iosScheme)));
    expect(changes.keys, isNot(contains(_macosScheme)));

    project.logger.lines.clear();
    await project.run(['plan']);

    expect(
      project.logger.output,
      allOf(
        contains('Left in place'),
        contains('$_iosScheme (flavorizr did not make it'),
        contains('$_macosScheme (flavorizr did not make it'),
      ),
    );

    final code = await project.run(['apply', '--yes']);

    expect(code, ExitCodes.ok, reason: project.logger.output);
    expect(project.exists(_iosScheme), isTrue);
    expect(project.exists(_macosScheme), isTrue);
  });

  test('leaves the copies 2.x made when 3.x never made them', () async {
    expect(await project.run(['adopt']), ExitCodes.ok);
    dropBanana();

    await project.run(['apply', '--yes']);

    for (final copy in [_iosCopy, _macosCopy, _androidCopy]) {
      expect(project.exists(copy), isTrue, reason: copy);
    }
  });

  test('removes the copies a run of 3.x made, and still leaves the schemes '
      'of 2.x', () async {
    expect(await project.run(['apply', '--yes']), ExitCodes.ok);
    dropBanana();

    final code = await project.run(['apply', '--yes']);

    expect(code, ExitCodes.ok, reason: project.logger.output);
    for (final copy in [_iosCopy, _macosCopy, _androidCopy]) {
      expect(project.exists(copy), isFalse, reason: copy);
    }
    expect(project.exists(_iosScheme), isTrue);
    expect(project.exists(_macosScheme), isTrue);
  });
}
