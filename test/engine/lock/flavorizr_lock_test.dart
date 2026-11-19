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

import 'package:flutter_flavorizr/src/engine/lock/flavorizr_lock.dart';
import 'package:flutter_flavorizr/src/engine/ownership.dart';
import 'package:test/test.dart';

void main() {
  group('LockedFile', () {
    test('records the hash of the hashed classes', () {
      final managed = LockedFile(ownership: Ownership.managed, hash: 'h1');
      final patched = LockedFile(ownership: Ownership.patched, hash: 'h2');

      expect(managed.hash, 'h1');
      expect(patched.hash, 'h2');
    });

    test('records a scaffold without a hash', () {
      final scaffold = LockedFile(ownership: Ownership.scaffold);

      expect(scaffold.hash, isNull);
    });

    test('never stores a local artifact', () {
      expect(() => LockedFile(ownership: Ownership.local), throwsArgumentError);
      expect(
        () => LockedFile(ownership: Ownership.local, hash: 'h'),
        throwsArgumentError,
      );
    });

    test('requires a hash for the hashed classes', () {
      expect(
        () => LockedFile(ownership: Ownership.managed),
        throwsArgumentError,
      );
      expect(
        () => LockedFile(ownership: Ownership.patched),
        throwsArgumentError,
      );
    });

    test('refuses a hash for a class that is not hashed', () {
      expect(
        () => LockedFile(ownership: Ownership.scaffold, hash: 'h'),
        throwsArgumentError,
      );
    });
  });

  group('FlavorizrLock', () {
    test('tells the names of the flavors it recorded', () {
      final lock = FlavorizrLock(
        flavorizrVersion: '3.0.0',
        flavors: {'prod': 'h1', 'dev': 'h2'},
      );

      expect(lock.flavorNames, {'dev', 'prod'});
    });

    test('is not changed by the maps it was built from', () {
      final flavors = {'dev': 'h1'};
      final lock = FlavorizrLock(flavorizrVersion: '3.0.0', flavors: flavors);

      flavors['prod'] = 'h2';

      expect(lock.flavorNames, {'dev'});
      expect(() => lock.flavors['prod'] = 'h2', throwsUnsupportedError);
    });
  });
}
