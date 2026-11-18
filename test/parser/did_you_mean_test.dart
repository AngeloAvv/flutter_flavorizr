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

import 'package:flutter_flavorizr/src/parser/did_you_mean.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const known = ['bundleId', 'applicationId', 'name', 'buildSettings'];

  group('didYouMean', () {
    test('takes another spelling of a key for the key', () {
      expect(didYouMean('bundle_id', known), 'bundleId');
      expect(didYouMean('bundle-id', known), 'bundleId');
      expect(didYouMean('BundleID', known), 'bundleId');
      expect(didYouMean('application_id', known), 'applicationId');
    });

    test('finds a typo', () {
      expect(didYouMean('buildSettigns', known), 'buildSettings');
      expect(didYouMean('nmae', known), 'name');
      expect(didYouMean('bundleI', known), 'bundleId');
    });

    test(
      'has nothing to say about a key that is nothing like the known ones',
      () {
        expect(didYouMean('zzzzzzzz', known), isNull);
        expect(didYouMean('flavor', known), isNull);
        expect(didYouMean('x', const []), isNull);
      },
    );
  });
}
