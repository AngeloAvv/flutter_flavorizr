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

import 'package:flutter_flavorizr/src/processors/ios/launch_screen/launch_assets.dart';
import 'package:test/test.dart';

void main() {
  group('launchScreenStoryboard', () {
    test('names the image of the flavor, and leaves no placeholder', () {
      final storyboard = launchScreenStoryboard('apple');

      expect(storyboard, isNot(contains('[[FLAVOR_NAME]]')));
      expect(storyboard, contains('image="appleLaunchImage"'));
      expect(storyboard, contains('<image name="appleLaunchImage"'));
      expect(storyboard, startsWith('<?xml version="1.0" encoding="UTF-8"?>'));
      expect(storyboard, endsWith('</document>\n'));
    });

    test('is the same document for every flavor but the name', () {
      expect(
        launchScreenStoryboard('banana').replaceAll('banana', 'apple'),
        launchScreenStoryboard('apple'),
      );
    });
  });

  group('launchImageFiles', () {
    test('has the contents, which name the three images', () {
      final contents = jsonDecode(launchImageContents) as Map;
      final names = [
        for (final image in contents['images'] as List)
          (image as Map)['filename'],
      ];

      expect(names, [
        'LaunchImage.png',
        'LaunchImage@2x.png',
        'LaunchImage@3x.png',
      ]);
      expect(launchImageFiles.keys, ['Contents.json', ...names]);
    });

    test('has images that are PNG files', () {
      for (final name in launchImageFiles.keys.where(
        (n) => n.endsWith('.png'),
      )) {
        expect(launchImageFiles[name]!.take(8), [
          0x89,
          0x50,
          0x4e,
          0x47,
          0x0d,
          0x0a,
          0x1a,
          0x0a,
        ], reason: name);
      }
    });
  });
}
