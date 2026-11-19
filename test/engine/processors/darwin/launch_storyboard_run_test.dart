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
import 'package:image/image.dart' as img;
import 'package:test/test.dart';

import '../../../entrypoint/cli_fixture.dart';
import '../../darwin/pristine_project.dart';

const _plist = 'ios/Runner/Info.plist';
const _run = ['ios:plist', 'ios:xcconfig', 'ios:launchScreen'];

String _config({String root = '', String apple = '', String banana = ''}) =>
    '''
${root}flavors:
  apple:
    app:
      name: "Apple"
      icon: assets/icon.png
    ios:
      bundleId: "com.example.apple"
$apple  banana:
    app:
      name: "Banana"
      icon: assets/icon.png
    ios:
      bundleId: "com.example.banana"
$banana''';

void main() {
  late CliFixture project;
  late Directory temp;

  Future<int> apply() => project.run(['apply', '--yes', ..._run]);

  /// The `UILaunchStoryboardName` the plist has.
  String storyboard() => RegExp(
    r'UILaunchStoryboardName</key>\s*<string>([^<]*)</string>',
  ).firstMatch(project.read(_plist))!.group(1)!;

  setUpAll(() {
    temp = Directory.systemTemp.createTempSync('flavorizr_storyboard_run_');
  });
  tearDownAll(() => temp.deleteSync(recursive: true));

  setUp(() async {
    project = CliFixture(android: false);
    project.write(
      'ios/Runner.xcodeproj/project.pbxproj',
      await pristineIosPbxproj(temp),
    );
    project.write(
      _plist,
      File(
        'test_resources/darwin/info_plist_test/IosInfoPlistOriginal.plist',
      ).readAsStringSync().replaceFirst(
        '<string>LaunchScreen</string>',
        '<string>CustomLaunch</string>',
      ),
    );
    File(project.abs('assets/icon.png'))
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(
        img.encodePng(
          img.Image(width: 1024, height: 1024)..clear(img.ColorRgb8(1, 2, 3)),
        ),
      );
    project.write('flavorizr.yaml', _config());
  });
  tearDown(() => project.dispose());

  group('a project with a launch storyboard of its own', () {
    test('keeps it for the flavor that has no launch screen', () async {
      project.write(
        'flavorizr.yaml',
        _config(apple: '    launchScreen: true\n'),
      );

      expect(await apply(), ExitCodes.ok, reason: project.logger.output);

      expect(storyboard(), r'$(LAUNCH_SCREEN_NAME)');
      expect(
        project.read('ios/Flutter/appleDebug.xcconfig'),
        contains('LAUNCH_SCREEN_NAME=appleLaunchScreen'),
      );
      expect(
        project.read('ios/Flutter/bananaDebug.xcconfig'),
        allOf(
          contains('DEFAULT_LAUNCH_SCREEN_NAME=CustomLaunch\n'),
          contains('LAUNCH_SCREEN_NAME=\$(DEFAULT_LAUNCH_SCREEN_NAME)\n'),
        ),
      );
    });

    test('is back to it when the last launch screen is turned off', () async {
      project.write('flavorizr.yaml', _config(root: 'launchScreen: true\n'));
      await apply();

      expect(storyboard(), r'$(LAUNCH_SCREEN_NAME)');

      project.write('flavorizr.yaml', _config());

      expect(await apply(), ExitCodes.ok, reason: project.logger.output);
      expect(storyboard(), 'CustomLaunch');
      expect(
        project.read('ios/Flutter/appleDebug.xcconfig'),
        isNot(contains('LAUNCH_SCREEN')),
      );
    });

    test('is still the one it kept after more runs', () async {
      project.write(
        'flavorizr.yaml',
        _config(banana: '    launchScreen: true\n'),
      );
      await apply();
      await apply();

      expect(
        project.read('ios/Flutter/appleDebug.xcconfig'),
        contains('DEFAULT_LAUNCH_SCREEN_NAME=CustomLaunch\n'),
      );
    });
  });
}
