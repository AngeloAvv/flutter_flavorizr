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

import 'package:flutter_flavorizr/src/engine/processors/darwin/launch_screen_sources.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

void main() {
  group('launchScreenStoryboard', () {
    test('is a well formed document, whatever the flavor', () {
      for (final flavor in ['apple', 'dev-1', 'a.b', 'x_y', 'a&b', 'a<b']) {
        expect(
          () => XmlDocument.parse(launchScreenStoryboard(flavor)),
          returnsNormally,
          reason: flavor,
        );
      }
    });

    test('shows the image of the flavor and nothing else', () {
      final document = XmlDocument.parse(launchScreenStoryboard('apple'));
      final views = document.findAllElements('imageView').toList();

      expect(views, hasLength(1));
      expect(views.single.getAttribute('image'), 'appleLaunchImage');
      expect(
        document
            .findAllElements('image')
            .map((e) => e.getAttribute('name'))
            .toList(),
        ['appleLaunchImage'],
      );
      expect(document.findAllElements('label'), isEmpty);
      expect(document.findAllElements('button'), isEmpty);
    });

    test('centres the image on the system background colour', () {
      final document = XmlDocument.parse(launchScreenStoryboard('apple'));
      final view = document
          .findAllElements('view')
          .singleWhere((e) => e.getAttribute('key') == 'view');
      final background = view.childElements.singleWhere(
        (e) => e.getAttribute('key') == 'backgroundColor',
      );
      final constraints = [
        for (final c in view.findAllElements('constraint'))
          c.getAttribute('firstAttribute'),
      ];

      expect(background.getAttribute('systemColor'), 'systemBackgroundColor');
      expect(constraints, containsAll(['centerX', 'centerY']));
    });

    test('gives the image a size the imageset has pixels for', () {
      final document = XmlDocument.parse(launchScreenStoryboard('apple'));
      final image = document.findAllElements('image').single;

      expect(image.getAttribute('width'), '$launchImagePoints');
      expect(image.getAttribute('height'), '$launchImagePoints');
      expect(
        document
            .findAllElements('constraint')
            .where((c) => c.getAttribute('constant') != null)
            .map((c) => c.getAttribute('constant')),
        everyElement('$launchImagePoints'),
      );
    });

    test('sizes the image view, not the view it is in', () {
      final document = XmlDocument.parse(launchScreenStoryboard('apple'));
      final image = document.findAllElements('imageView').single;
      final sizes = document
          .findAllElements('constraint')
          .where((c) => c.getAttribute('constant') != null)
          .toList();

      expect(sizes.map((c) => c.getAttribute('firstAttribute')), [
        'width',
        'height',
      ]);
      expect(
        sizes.map((c) => c.getAttribute('firstItem')),
        everyElement(image.getAttribute('id')),
      );
    });

    test('is the same document for every flavor but the name', () {
      expect(
        launchScreenStoryboard('banana').replaceAll('banana', 'apple'),
        launchScreenStoryboard('apple'),
      );
    });

    test('says that flavorizr made it', () {
      expect(isGeneratedLaunchScreen(launchScreenStoryboard('apple')), isTrue);
    });

    test('is not mistaken for the storyboard 2.x copied, or the user\'s', () {
      expect(isGeneratedLaunchScreen('<document/>'), isFalse);
      expect(isGeneratedLaunchScreen(''), isFalse);
    });
  });

  group('launchImageContents', () {
    final contents = jsonDecode(launchImageContents) as Map;

    test('names the three images of the three scales', () {
      expect(
        [
          for (final image in contents['images'] as List)
            ((image as Map)['scale'], image['filename']),
        ],
        [
          ('1x', 'LaunchImage.png'),
          ('2x', 'LaunchImage@2x.png'),
          ('3x', 'LaunchImage@3x.png'),
        ],
      );
    });

    test('has the pixels of each scale', () {
      expect(launchImageSizes, {
        'LaunchImage.png': launchImagePoints,
        'LaunchImage@2x.png': launchImagePoints * 2,
        'LaunchImage@3x.png': launchImagePoints * 3,
      });
    });

    test('says that flavorizr made it', () {
      expect(isGeneratedLaunchImage(launchImageContents), isTrue);
    });

    test('is not mistaken for the Contents.json 2.x copied', () {
      expect(
        isGeneratedLaunchImage(
          launchImageContents.replaceAll('flavorizr', 'xcode'),
        ),
        isFalse,
      );
      expect(isGeneratedLaunchImage('not json'), isFalse);
      expect(isGeneratedLaunchImage('[]'), isFalse);
    });
  });
}
