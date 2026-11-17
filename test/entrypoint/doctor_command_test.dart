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

import 'package:flutter_flavorizr/src/entrypoint/exit_codes.dart';
import 'package:flutter_test/flutter_test.dart';

import 'cli_fixture.dart';

String _withIos() =>
    '${CliFixture.config(['apple'])}'
    '    ios:\n      bundleId: "com.example.apple"\n';

void main() {
  late CliFixture project;

  setUp(() => project = CliFixture());
  tearDown(() => project.dispose());

  group('doctor', () {
    test('has nothing to say about a healthy project', () async {
      final code = await project.run(['doctor']);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.logger.output, contains('2 flavors (apple, banana)'));
      expect(project.logger.output, contains('build scripts in Groovy'));
      expect(project.logger.output, contains('Flutter: 3.47.9'));
      expect(project.logger.output, contains('no flavorizr.lock yet'));
      expect(project.logger.output, contains('No problem found'));
    });

    test('tells Kotlin from Groovy', () async {
      File(project.abs('android/app/build.gradle')).deleteSync();
      project.write('android/app/build.gradle.kts', 'android {\n}\n');

      final code = await project.run(['doctor']);

      expect(code, ExitCodes.ok);
      expect(project.logger.output, contains('build scripts in Kotlin'));
    });

    test('warns about both of them, which is not a failure', () async {
      project.write('android/app/build.gradle.kts', 'android {\n}\n');

      final code = await project.run(['doctor']);

      expect(code, ExitCodes.ok);
      expect(project.logger.output, contains('both build.gradle'));
    });

    test('fails when the android flavors have no build script', () async {
      File(project.abs('android/app/build.gradle')).deleteSync();

      final code = await project.run(['doctor']);

      expect(code, ExitCodes.attention);
      expect(project.logger.errors.join(), contains('build.gradle.kts'));
    });

    test('fails outside of a project', () async {
      File(project.abs('pubspec.yaml')).deleteSync();

      final code = await project.run(['doctor']);

      expect(code, ExitCodes.attention);
      expect(project.logger.errors.join(), contains('pubspec.yaml not found'));
    });

    test('fails on a configuration that cannot be read, and goes on', () async {
      project.write('flavorizr.yaml', 'flavors: [');

      final code = await project.run(['doctor']);

      expect(code, ExitCodes.attention);
      expect(project.logger.output, contains('Flutter: 3.47.9'));
    });

    test('fails on a lock that cannot be read', () async {
      project.write('flavorizr.lock', '[');

      final code = await project.run(['doctor']);

      expect(code, ExitCodes.attention);
      expect(project.logger.errors.join(), contains('flavorizr.lock'));
    });

    test('says which flavorizr wrote the lock', () async {
      await project.run(['apply', '-y', ...engineTargets]);

      await project.run(['doctor']);

      expect(
        project.logger.output,
        contains('written by flutter_flavorizr 3.0.0'),
      );
    });

    test('fails when ios flavors have no ios folder', () async {
      project.write('flavorizr.yaml', _withIos());

      final code = await project.run(['doctor']);

      expect(code, ExitCodes.attention);
      expect(project.logger.errors.join(), contains('`ios` folder'));
    });

    test('checks the layout of the Xcode project and the Pods', () async {
      project.write('flavorizr.yaml', _withIos());
      project.write('ios/Runner.xcodeproj/project.pbxproj', '');
      project.write('ios/Runner.xcworkspace/contents.xcworkspacedata', '');
      project.write('ios/Podfile', '');

      final code = await project.run(['doctor']);

      expect(code, ExitCodes.ok);
      expect(project.logger.output, contains('Xcode (ios)'));
      expect(
        project.logger.output,
        contains('not installed: run `pod install`'),
      );

      Directory(project.abs('ios/Pods')).createSync();
      project.logger.lines.clear();
      await project.run(['doctor']);

      expect(project.logger.output, contains('Pods (ios): installed'));
    });

    test('fails when the Xcode project is not the one of Flutter', () async {
      project.write('flavorizr.yaml', _withIos());
      project.write('ios/Podfile', '');

      final code = await project.run(['doctor']);

      expect(code, ExitCodes.attention);
      expect(project.logger.errors.join(), contains('Runner.xcodeproj'));
    });

    test(
      'warns about a Flutter that is not found, which is not a failure',
      () async {
        project.flutterVersion = null;

        final code = await project.run(['doctor']);

        expect(code, ExitCodes.ok);
        expect(project.logger.output, contains('Flutter: not found'));
      },
    );

    test('writes nothing', () async {
      final before = project.snapshot();

      await project.run(['doctor']);

      expect(project.snapshot(), before);
    });
  });
}
