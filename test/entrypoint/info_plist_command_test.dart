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

import 'package:flutter_flavorizr/src/engine/lock/lock_store.dart';
import 'package:flutter_flavorizr/src/engine/ownership.dart';
import 'package:flutter_flavorizr/src/entrypoint/exit_codes.dart';
import 'package:test/test.dart';

import 'cli_fixture.dart';

const _ios = 'ios/Runner/Info.plist';
const _macos = 'macos/Runner/Info.plist';
const _plist = ['ios:plist', 'macos:plist'];

/// What a full run of a project with only iOS and macOS flavors covers.
const _run = [
  'flutter:flavors',
  'ios:plist',
  'macos:plist',
  'ios:xcconfig',
  'ios:schema',
  'macos:xcconfig',
  'macos:configs',
  'macos:schema',
  'ios:buildTargets',
  'macos:buildTargets',
  'ios:podfile',
  'macos:podfile',
];

final String _iosPristine = File(
  'test_resources/darwin/info_plist_test/IosInfoPlistOriginal.plist',
).readAsStringSync().replaceAll('\r\n', '\n');
final String _macosPristine = File(
  'test_resources/darwin/info_plist_test/MacosInfoPlistOriginal.plist',
).readAsStringSync().replaceAll('\r\n', '\n');

String _config(Iterable<String> flavors) =>
    'flavors:\n${[for (final flavor in flavors) '''
  $flavor:
    app:
      name: "$flavor app"
    ios:
      bundleId: "com.example.$flavor"
    macos:
      bundleId: "com.example.$flavor"
'''].join()}';

void main() {
  late CliFixture project;

  setUp(() {
    project = CliFixture(android: false);
    project.write('flavorizr.yaml', _config(['apple', 'banana']));
    project.write(_ios, _iosPristine);
    project.write(_macos, _macosPristine);
    for (final platform in ['ios', 'macos']) {
      project.write(
        '$platform/Podfile',
        File(
          'test_resources/darwin/podfile_test/PodfileOriginal',
        ).readAsStringSync(),
      );
    }
    for (final platform in ['ios', 'macos']) {
      final path = '$platform/Runner.xcodeproj/project.pbxproj';
      project.write(
        path,
        File('test_resources/example_2x/$path').readAsStringSync(),
      );
    }
  });
  tearDown(() => project.dispose());

  group('the Info.plist processors on the engine', () {
    test('plan lists them on the engine and none for the legacy pipeline, '
        'and writes nothing', () async {
      final before = project.snapshot();

      final code = await project.run(['plan', ..._plist]);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.logger.output, contains('1. ios:plist'));
      expect(project.logger.output, contains('macos:plist'));
      expect(project.logger.output, isNot(contains('not on the engine')));
      expect(project.snapshot(), before);
    });

    test('apply on a pristine plist changes only the owned key lines, and '
        'the legacy pipeline does not run', () async {
      final code = await project.run(['apply', '--yes', ..._run]);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.legacy.ran, isEmpty);
      expect(
        project.read(_ios),
        _iosPristine
            .replaceFirst(
              '<key>CFBundleDisplayName</key>\n\t<string>Example</string>',
              r'<key>CFBundleDisplayName</key>'
                  '\n\t'
                  r'<string>$(BUNDLE_DISPLAY_NAME)</string>',
            )
            .replaceFirst(
              '<key>CFBundleName</key>\n\t<string>example</string>',
              r'<key>CFBundleName</key>'
                  '\n\t'
                  r'<string>$(BUNDLE_NAME)</string>',
            ),
      );
      expect(
        project.read(_macos),
        _macosPristine.replaceFirst(
          '<key>CFBundleName</key>\n\t<string>\$(PRODUCT_NAME)</string>',
          r'<key>CFBundleName</key>'
              '\n\t'
              r'<string>$(BUNDLE_NAME)</string>',
        ),
      );
    });

    test('apply records the plists as patched in the lock', () async {
      await project.run(['apply', '--yes', ..._run]);

      final lock = (await LockStore(
        project.root,
        runningVersion: '3.0.0',
      ).read())!;

      for (final (id, path) in [('ios:plist', _ios), ('macos:plist', _macos)]) {
        expect(lock.processors[id]!.files[path]!.ownership, Ownership.patched);
      }
    });

    test('an idempotent re-run produces an empty diff', () async {
      await project.run(['apply', '--yes', ..._run]);
      final before = project.snapshot();
      project.questions.clear();

      final code = await project.run(['apply', ..._run]);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.questions, isEmpty);
      expect(project.snapshot(), before);
    });

    test('status is in sync once applied', () async {
      await project.run(['apply', '--yes', ..._run]);

      final code = await project.run(['status', ..._run]);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.logger.output, contains('In sync'));
    });

    test('what the user writes outside the owned keys is no drift and '
        'survives the next run', () async {
      await project.run(['apply', '--yes', ..._run]);
      project.write(
        _ios,
        project
            .read(_ios)
            .replaceFirst('<false/>', '<true/>')
            .replaceAll('\t', '    ')
            .replaceFirst('<dict>\n', '<dict>\n<!-- mine -->\n'),
      );
      final edited = project.snapshot();

      expect(await project.run(['status', ..._run]), ExitCodes.ok);
      expect(await project.run(['apply', '--yes', ..._run]), ExitCodes.ok);
      expect(project.snapshot(), edited);
    });

    test(
      'a hand edit of an owned key is a conflict, and nothing is written',
      () async {
        await project.run(['apply', '--yes', ..._run]);
        project.write(
          _ios,
          project.read(_ios).replaceFirst(r'$(BUNDLE_DISPLAY_NAME)', 'My App'),
        );
        final before = project.snapshot();

        final code = await project.run(['apply', '--yes', ..._run]);

        expect(code, ExitCodes.attention, reason: project.logger.output);
        expect(project.snapshot(), before);
        expect(project.logger.output, contains(_ios));
      },
    );

    test('a plist that was reformatted by 2.x is adopted, and the only '
        'difference is the owned keys', () async {
      // What 2.x wrote: the owned keys set, the whole document reindented.
      final flavorized = _iosPristine
          .replaceFirst('Example', r'$(BUNDLE_DISPLAY_NAME)')
          .replaceFirst('example', r'$(BUNDLE_NAME)')
          .replaceAll('\t', '  ');
      project.write(_ios, flavorized);

      final code = await project.run(['apply', '--yes', ..._run]);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.read(_ios), flavorized);
    });

    test('the launch storyboard follows the launch screen of the flavors, not '
        'the processors of the run', () async {
      // The run asks for the launch screen, the flavors do not.
      project.write(
        'flavorizr.yaml',
        'recipes:\n  default:\n    - ios:plist\n    - ios:launchScreen\n'
            '${_config(['apple', 'banana'])}',
      );

      expect(await project.run(['apply', '--yes', 'ios:plist']), ExitCodes.ok);
      expect(project.read(_ios), isNot(contains('LAUNCH_SCREEN_NAME')));

      // The flavors ask for it, the run is only the plist.
      project.write(
        'flavorizr.yaml',
        'launchScreen: true\n${_config(['apple', 'banana'])}',
      );

      expect(
        await project.run(['apply', '--yes', 'ios:plist']),
        ExitCodes.ok,
        reason: project.logger.output,
      );
      expect(
        project.read(_ios),
        contains(r'<string>$(LAUNCH_SCREEN_NAME)</string>'),
      );
    });

    test('a plist without the key fails the run, and writes nothing', () async {
      project.write(
        _ios,
        _iosPristine.replaceAll('CFBundleDisplayName', 'CFBundleOther'),
      );
      final before = project.snapshot();

      final code = await project.run(['apply', '--yes', ..._run]);

      expect(code, ExitCodes.software, reason: project.logger.output);
      expect(project.logger.output, contains('ios:plist'));
      expect(project.logger.output, contains('malformed'));
      expect(project.snapshot(), before);
    });
  });
}
