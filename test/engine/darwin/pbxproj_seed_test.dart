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

import 'package:dart_xcodeproj/dart_xcodeproj.dart';
import 'package:flutter_flavorizr/src/engine/darwin/pbxproj_seed.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PbxprojSeed', () {
    test(
      'spells the seed as flavorizr/<platform>/<target>/<flavor>/<kind>',
      () {
        expect(
          PbxprojSeed.of(
            platform: 'ios',
            target: 'Runner',
            flavor: 'dev',
            kind: ['buildConfiguration', 'Debug'],
          ),
          'flavorizr/ios/Runner/dev/buildConfiguration/Debug',
        );
      },
    );

    test('a seed without a target is the one of the project', () {
      expect(
        PbxprojSeed.of(
          platform: 'macos',
          flavor: 'dev',
          kind: ['buildConfiguration', 'Debug'],
        ),
        'flavorizr/macos/@project/dev/buildConfiguration/Debug',
      );
    });

    test('a seed without a flavor is the one of every flavor', () {
      expect(
        PbxprojSeed.of(
          platform: 'ios',
          target: 'Runner',
          kind: ['shellScriptBuildPhase', 'firebase'],
        ),
        'flavorizr/ios/Runner/@all/shellScriptBuildPhase/firebase',
      );
    });

    test('the UUID is 24 uppercase hex characters Xcode accepts', () {
      final uuid = PbxprojSeed.uuid(
        platform: 'ios',
        target: 'Runner',
        flavor: 'dev',
        kind: ['buildConfiguration', 'Debug'],
      );

      expect(uuid, hasLength(24));
      expect(UuidGenerator.isValid(uuid), isTrue);
      expect(
        uuid,
        UuidGenerator.deterministic(
          'flavorizr/ios/Runner/dev/buildConfiguration/Debug',
        ),
      );
    });

    test(
      'the same seed is always the same UUID, and any change of it is not',
      () {
        String uuid({
          String platform = 'ios',
          String? target = 'Runner',
          String? flavor = 'dev',
          List<String> kind = const ['buildConfiguration', 'Debug'],
        }) => PbxprojSeed.uuid(
          platform: platform,
          target: target,
          flavor: flavor,
          kind: kind,
        );

        final all = {
          uuid(),
          uuid(platform: 'macos'),
          uuid(target: 'Other'),
          uuid(target: null),
          uuid(flavor: 'prod'),
          uuid(flavor: null),
          uuid(kind: ['buildConfiguration', 'Release']),
          uuid(kind: ['fileReference', 'Debug']),
        };

        expect(uuid(), uuid());
        expect(all, hasLength(8));
      },
    );

    test('a segment cannot hide a separator, so seeds are never ambiguous', () {
      for (final bad in ['a/b', '', r'a\b']) {
        expect(
          () => PbxprojSeed.of(platform: 'ios', flavor: bad, kind: ['x']),
          throwsArgumentError,
          reason: 'flavor "$bad"',
        );
        expect(
          () => PbxprojSeed.of(platform: 'ios', target: bad, kind: ['x']),
          throwsArgumentError,
          reason: 'target "$bad"',
        );
        expect(
          () => PbxprojSeed.of(platform: 'ios', kind: ['x', bad]),
          throwsArgumentError,
          reason: 'kind "$bad"',
        );
      }
    });

    test('the markers of the project and of every flavor are reserved', () {
      expect(
        () => PbxprojSeed.of(platform: 'ios', flavor: '@all', kind: ['x']),
        throwsArgumentError,
      );
      expect(
        () => PbxprojSeed.of(platform: 'ios', target: '@project', kind: ['x']),
        throwsArgumentError,
      );
    });

    test('needs a known platform and a kind', () {
      expect(
        () => PbxprojSeed.of(platform: 'tvos', kind: ['x']),
        throwsArgumentError,
      );
      expect(
        () => PbxprojSeed.of(platform: 'ios', kind: const []),
        throwsArgumentError,
      );
    });
  });
}
