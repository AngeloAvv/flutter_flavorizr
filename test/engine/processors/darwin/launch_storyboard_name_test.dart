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

import 'package:flutter_flavorizr/src/engine/processors/darwin/launch_storyboard_name.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

String _plist(String? storyboard) =>
    '''
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
	<key>CFBundleName</key>
	<string>example</string>
${storyboard == null ? '' : '\t<key>UILaunchStoryboardName</key>\n\t<string>$storyboard</string>\n'}</dict>
</plist>
''';

void main() {
  late Directory project;

  setUp(() {
    project = Directory.systemTemp.createTempSync('flavorizr_storyboard_');
    addTearDown(() => project.deleteSync(recursive: true));
  });

  void write(String path, String content) => File(p.join(project.path, path))
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(content);

  String original({String? plistSource}) =>
      originalLaunchStoryboardName(project, plistSource: plistSource);

  group('originalLaunchStoryboardName', () {
    test('is the storyboard of Flutter when there is nothing to read', () {
      expect(original(), 'LaunchScreen');
    });

    test('is the storyboard the plist has, whatever it is', () {
      write('ios/Runner/Info.plist', _plist('CustomLaunch'));

      expect(original(), 'CustomLaunch');
    });

    test(
      'is the one 2.x set, which points at the storyboard of the flavor',
      () {
        write('ios/Runner/Info.plist', _plist(r'$(ASSET_PREFIX)LaunchScreen'));

        expect(original(), r'$(ASSET_PREFIX)LaunchScreen');
      },
    );

    test('reads the plist it is given instead of the one of the project', () {
      write('ios/Runner/Info.plist', _plist('Other'));

      expect(original(plistSource: _plist('CustomLaunch')), 'CustomLaunch');
    });

    test('is the one an earlier run kept in the xcconfig of a flavor, once the '
        'plist points at LAUNCH_SCREEN_NAME', () {
      write('ios/Runner/Info.plist', _plist(r'$(LAUNCH_SCREEN_NAME)'));
      write(
        'ios/Flutter/appleDebug.xcconfig',
        '#include "Generated.xcconfig"\n\nDEFAULT_LAUNCH_SCREEN_NAME=CustomLaunch\n'
            'LAUNCH_SCREEN_NAME=appleLaunchScreen\n',
      );

      expect(original(), 'CustomLaunch');
    });

    test('is the storyboard of Flutter when the plist points at '
        'LAUNCH_SCREEN_NAME and nothing kept the original', () {
      write('ios/Runner/Info.plist', _plist(r'$(LAUNCH_SCREEN_NAME)'));

      expect(original(), 'LaunchScreen');
    });

    test('is the storyboard of Flutter for a plist that cannot be read', () {
      write('ios/Runner/Info.plist', '<plist><dict>');

      expect(original(), 'LaunchScreen');
    });

    test('is the storyboard of Flutter for a plist without the key', () {
      write('ios/Runner/Info.plist', _plist(null));

      expect(original(), 'LaunchScreen');
    });
  });
}
