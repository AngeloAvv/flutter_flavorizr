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

import 'package:flutter_flavorizr/src/badge/badge_source_icon.dart';
import 'package:test/test.dart';

/// A project that is a map of paths: a text is the content of a text file, a
/// number is the shorter side of an image.
class _FakeFiles implements BadgeSourceFiles {
  final Map<String, Object> files;

  _FakeFiles(this.files);

  @override
  String? readText(String path) {
    final file = files[path];

    return file is String ? file : null;
  }

  @override
  int? imageSize(String path) {
    final file = files[path];

    return file is int ? file : null;
  }
}

const _iosSet = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
const _macosSet = 'macos/Runner/Assets.xcassets/AppIcon.appiconset';

String _contents(List<(String size, String scale, String? file)> images) =>
    '{"images":[${[for (final (size, scale, file) in images) '{"size":"$size","scale":"$scale",'
          '"idiom":"universal"${file == null ? '' : ',"filename":"$file"'}}'].join(',')}],'
    '"info":{"version":1,"author":"xcode"}}';

void main() {
  group('resolveBadgeSourceIcon', () {
    test('is the icon of the flavor first', () {
      final icon = resolveBadgeSourceIcon(
        flavorIcon: 'assets/dev.png',
        rootIcon: 'assets/root.png',
        files: _FakeFiles({'assets/dev.png': 1024, 'assets/root.png': 1024}),
      );

      expect(icon.path, 'assets/dev.png');
      expect(icon.origin, BadgeSourceOrigin.flavor);
      expect(icon.size, 1024);
    });

    test('is the root icon when the flavor has none', () {
      final icon = resolveBadgeSourceIcon(
        rootIcon: 'assets/root.png',
        files: _FakeFiles({'assets/root.png': 512}),
      );

      expect(icon.path, 'assets/root.png');
      expect(icon.origin, BadgeSourceOrigin.root);
      expect(icon.size, 512);
    });

    test('is the 1024 px AppIcon of iOS when there is no icon set', () {
      final icon = resolveBadgeSourceIcon(
        files: _FakeFiles({
          '$_iosSet/Contents.json': _contents([
            ('20x20', '2x', 'Icon-App-20x20@2x.png'),
            ('1024x1024', '1x', 'Icon-App-1024x1024@1x.png'),
          ]),
          '$_iosSet/Icon-App-20x20@2x.png': 40,
          '$_iosSet/Icon-App-1024x1024@1x.png': 1024,
        }),
      );

      expect(icon.path, '$_iosSet/Icon-App-1024x1024@1x.png');
      expect(icon.origin, BadgeSourceOrigin.project);
      expect(icon.size, 1024);
    });

    test('is the AppIcon of macOS when iOS has none', () {
      final icon = resolveBadgeSourceIcon(
        files: _FakeFiles({
          '$_macosSet/Contents.json': _contents([
            ('16x16', '1x', 'app_icon_16.png'),
            ('512x512', '2x', 'app_icon_1024.png'),
            ('512x512', '1x', 'app_icon_512.png'),
          ]),
          '$_macosSet/app_icon_16.png': 16,
          '$_macosSet/app_icon_512.png': 512,
          '$_macosSet/app_icon_1024.png': 1024,
        }),
      );

      expect(icon.path, '$_macosSet/app_icon_1024.png');
      expect(icon.size, 1024);
    });

    test('is the AppIcon of macOS when the one of iOS is too small', () {
      final icon = resolveBadgeSourceIcon(
        files: _FakeFiles({
          '$_iosSet/Contents.json': _contents([('20x20', '2x', 'small.png')]),
          '$_iosSet/small.png': 40,
          '$_macosSet/Contents.json': _contents([('512x512', '2x', 'big.png')]),
          '$_macosSet/big.png': 1024,
        }),
      );

      expect(icon.path, '$_macosSet/big.png');
    });

    test('goes past an icon that is under 512 px, or is not there', () {
      final icon = resolveBadgeSourceIcon(
        flavorIcon: 'assets/dev.png',
        rootIcon: 'assets/root.png',
        files: _FakeFiles({'assets/dev.png': 511, 'assets/root.png': 600}),
      );

      expect(icon.path, 'assets/root.png');

      final project = resolveBadgeSourceIcon(
        flavorIcon: 'assets/missing.png',
        rootIcon: 'assets/root.png',
        files: _FakeFiles({'assets/root.png': 600}),
      );

      expect(project.path, 'assets/root.png');
    });

    test('ignores an image of the set that has no file', () {
      final icon = resolveBadgeSourceIcon(
        files: _FakeFiles({
          '$_iosSet/Contents.json': _contents([
            ('1024x1024', '1x', null),
            ('512x512', '1x', 'mid.png'),
          ]),
          '$_iosSet/mid.png': 512,
        }),
      );

      expect(icon.path, '$_iosSet/mid.png');
    });

    test('fails with a hint to set `icon:` when nothing is big enough', () {
      try {
        resolveBadgeSourceIcon(
          flavorIcon: 'assets/dev.png',
          files: _FakeFiles({
            'assets/dev.png': 256,
            '$_iosSet/Contents.json': _contents([('20x20', '2x', 'small.png')]),
            '$_iosSet/small.png': 40,
          }),
        );
      } on BadgeSourceIconException catch (e) {
        expect(e.toString(), contains('`icon:`'));
        expect(e.toString(), contains('512'));
        expect(e.toString(), contains('assets/dev.png'));
        expect(e.tried, contains('assets/dev.png'));

        return;
      }

      fail('Should have thrown BadgeSourceIconException');
    });

    test('fails when the project has no icon at all', () {
      expect(
        () => resolveBadgeSourceIcon(files: _FakeFiles({})),
        throwsA(isA<BadgeSourceIconException>()),
      );
    });

    test('fails on a Contents.json that is not JSON, or is not what Xcode '
        'writes', () {
      for (final content in ['not json', '[]', '{"images": 3}', '{}']) {
        expect(
          () => resolveBadgeSourceIcon(
            files: _FakeFiles({'$_iosSet/Contents.json': content}),
          ),
          throwsA(isA<BadgeSourceIconException>()),
          reason: content,
        );
      }
    });
  });
}
