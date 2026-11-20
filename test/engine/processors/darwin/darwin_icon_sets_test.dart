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

import 'dart:convert';
import 'dart:io';

import 'package:flutter_flavorizr/src/engine/processors/darwin/darwin_icon_sets.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// The file names of the dummy set that 2.6.0 wrote, which the parity harness
/// recorded: an independent list of what an appiconset of a platform holds.
Set<String> _recorded(String set) =>
    Directory(p.join('tool/parity/golden/2.6.0/tree', set))
        .listSync()
        .whereType<File>()
        .map((file) => p.basename(file.path).replaceAll('.sha256', ''))
        .toSet();

void main() {
  group('the icons of an appiconset', () {
    test('of iOS are the files 2.6.0 wrote', () {
      final names = {for (final icon in iosIconSet) icon.fileName};

      expect(
        names,
        _recorded('ios/Runner/Assets.xcassets/AppIcon-apple.appiconset')
          ..remove('Contents.json'),
      );
    });

    test('of macOS are the files 2.6.0 wrote', () {
      final names = {for (final icon in macosIconSet) icon.fileName};

      expect(
        names,
        _recorded('macos/Runner/Assets.xcassets/AppIcon-apple.appiconset')
          ..remove('Contents.json'),
      );
    });
  });

  group('darwinIconContents', () {
    test('lists every icon in order, then the info of Xcode', () {
      final contents = jsonDecode(darwinIconContents(iosIconSet)) as Map;

      expect(contents['info'], {'version': 1, 'author': 'xcode'});
      expect((contents['images'] as List).first, {
        'size': '20x20',
        'idiom': 'iphone',
        'scale': '2x',
        'filename': 'Icon-App-20x20@2x.png',
      });
      expect((contents['images'] as List).elementAt(17), {
        'size': '83.5x83.5',
        'idiom': 'ipad',
        'scale': '2x',
        'filename': 'Icon-App-83.5x83.5@2x.png',
      });
      expect((contents['images'] as List).last, {
        'size': '1024x1024',
        'idiom': 'ios-marketing',
        'scale': '1x',
        'filename': 'Icon-App-1024x1024@1x.png',
      });
    });

    // The fixtures are the Contents.json that 2.6.0 wrote (compact `jsonEncode`
    // of the icons in order), made with an independent implementation.
    for (final (name, icons) in [
      ('ios', iosIconSet),
      ('macos', macosIconSet),
    ]) {
      test('is, byte for byte, the Contents.json of 2.6.0 for $name', () {
        final recorded = File(
          'test_resources/darwin/icons_test/${name}_contents.json',
        ).readAsBytesSync();

        expect(utf8.encode(darwinIconContents(icons)), recorded);
      });
    }

    test('is compact, with no trailing newline, as 2.x wrote it', () {
      final text = darwinIconContents(macosIconSet);

      expect(text, isNot(contains('\n')));
      expect(text, isNot(contains(' ')));
    });

    test('is the same text every time', () {
      expect(darwinIconContents(iosIconSet), darwinIconContents(iosIconSet));
    });
  });
}
