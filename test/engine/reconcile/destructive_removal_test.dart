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
import 'package:flutter_flavorizr/src/engine/reconcile/destructive_removal.dart';
import 'package:flutter_flavorizr/src/exception/last_flavor_removal_exception.dart';
import 'package:flutter_flavorizr/src/exception/platform_drop_exception.dart';
import 'package:flutter_test/flutter_test.dart';

FlavorizrLock lockOf({
  Map<String, String> flavors = const {'dev': 'h1', 'prod': 'h2'},
  Map<String, List<String>> processors = const {
    'android:androidManifest': ['android/app/src/main/AndroidManifest.xml'],
  },
}) => FlavorizrLock(
  flavorizrVersion: '3.0.0',
  flavors: flavors,
  processors: {
    for (final MapEntry(:key, :value) in processors.entries)
      key: ProcessorLock(
        files: {
          for (final path in value)
            path: LockedFile(ownership: Ownership.scaffold),
        },
      ),
  },
);

void main() {
  group('checkRemoval', () {
    test('accepts a project that was never applied', () {
      expect(
        () => checkRemoval(previous: null, flavors: {}, platforms: {}),
        returnsNormally,
      );
    });

    test('accepts removing flavors down to one', () {
      expect(
        () => checkRemoval(
          previous: lockOf(),
          flavors: {'dev'},
          platforms: {'android'},
        ),
        returnsNormally,
      );
    });

    test('accepts a configuration that adds flavors and platforms', () {
      expect(
        () => checkRemoval(
          previous: lockOf(),
          flavors: {'dev', 'prod', 'beta'},
          platforms: {'android', 'ios'},
        ),
        returnsNormally,
      );
    });

    test('refuses to remove every flavor, naming them', () {
      expect(
        () => checkRemoval(previous: lockOf(), flavors: {}, platforms: {}),
        throwsA(
          isA<LastFlavorRemovalException>()
              .having((e) => e.flavors, 'flavors', ['dev', 'prod'])
              .having(
                (e) => e.toString(),
                'message',
                allOf(
                  contains('dev, prod'),
                  contains('android:label'),
                  contains('not stored'),
                  contains('out of scope'),
                  contains('flavorizr.lock'),
                ),
              ),
        ),
      );
    });

    test('refuses to remove every flavor when the lock has no platform', () {
      expect(
        () => checkRemoval(
          previous: lockOf(processors: {}),
          flavors: {},
          platforms: {},
        ),
        throwsA(isA<LastFlavorRemovalException>()),
      );
    });

    test('does not refuse a lock that records no flavors', () {
      // A partial run does not record the flavors.
      expect(
        () => checkRemoval(
          previous: lockOf(flavors: {}, processors: {}),
          flavors: {},
          platforms: {},
        ),
        returnsNormally,
      );
    });

    test('refuses to drop a platform the lock shows was flavorized', () {
      expect(
        () => checkRemoval(
          previous: lockOf(
            processors: {
              'android:androidManifest': ['a/AndroidManifest.xml'],
              'android:buildGradle': ['a/build.gradle'],
              'ios:xcconfig': ['ios/Flutter/dev.xcconfig'],
            },
          ),
          flavors: {'dev'},
          platforms: {'ios'},
        ),
        throwsA(
          isA<PlatformDropException>()
              .having((e) => e.platforms, 'platforms', ['android'])
              .having(
                (e) => e.toString(),
                'message',
                allOf(
                  contains('android'),
                  isNot(contains('ios')),
                  contains('a/AndroidManifest.xml'),
                  contains('a/build.gradle'),
                  contains('not stored'),
                  contains('out of scope'),
                ),
              ),
        ),
      );
    });

    test('names every dropped platform', () {
      expect(
        () => checkRemoval(
          previous: lockOf(
            processors: {
              'android:androidManifest': ['m.xml'],
              'macos:xcconfig': ['x.xcconfig'],
            },
          ),
          flavors: {'dev'},
          platforms: {},
        ),
        throwsA(
          isA<PlatformDropException>().having((e) => e.platforms, 'platforms', [
            'android',
            'macos',
          ]),
        ),
      );
    });

    test('ignores what the lock records for a platform without files', () {
      final lock = FlavorizrLock(
        flavorizrVersion: '3.0.0',
        flavors: {'dev': 'h1'},
        processors: {'android:icons': ProcessorLock()},
      );

      expect(
        () => checkRemoval(previous: lock, flavors: {'dev'}, platforms: {}),
        returnsNormally,
      );
    });

    test('ignores processors that are not a platform', () {
      expect(
        () => checkRemoval(
          previous: lockOf(
            processors: {
              'flutter:flavors': ['lib/flavors.dart'],
              'ide:config': ['.idea/x.xml'],
            },
          ),
          flavors: {'dev'},
          platforms: {},
        ),
        returnsNormally,
      );
    });
  });
}
