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

import 'package:flutter_flavorizr/src/utils/darwin_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('flatPath', () {
    test('strips a leading ios/ segment', () {
      expect(flatPath('ios/Runner/Info.plist'), 'Runner/Info.plist');
    });

    test('strips a leading macos/ segment', () {
      expect(flatPath('macos/Runner/Info.plist'), 'Runner/Info.plist');
    });

    test('strips ios/ and macos/ occurrences anywhere in the string', () {
      expect(flatPath('some/ios/nested/macos/path'), 'some/nested/path');
    });

    test('returns the string unchanged when no replacement applies', () {
      expect(flatPath('android/app/src/main'), 'android/app/src/main');
    });

    test('returns an empty string unchanged', () {
      expect(flatPath(''), '');
    });

    test('strips all repeated occurrences of ios/', () {
      expect(flatPath('ios/ios/ios/Runner'), 'Runner');
    });
  });
}
