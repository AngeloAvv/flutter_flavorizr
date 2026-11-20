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

import 'package:flutter_flavorizr/src/engine/artifact.dart';
import 'package:flutter_flavorizr/src/engine/ownership.dart';
import 'package:test/test.dart';

void main() {
  group('Artifact', () {
    test('every artifact is created with an ownership class', () {
      expect(
        const Artifact.scaffold('lib/main.dart').ownership,
        Ownership.scaffold,
      );
      expect(
        const Artifact.managed('lib/flavors.dart').ownership,
        Ownership.managed,
      );
      expect(
        const Artifact.patched('android/app/build.gradle').ownership,
        Ownership.patched,
      );
      expect(
        const Artifact.local('.vscode/launch.json').ownership,
        Ownership.local,
      );
    });

    test('keeps the path it was created with', () {
      expect(
        const Artifact.managed('lib/flavors.dart').path,
        'lib/flavors.dart',
      );
    });

    test('can be told apart by its subtype', () {
      const Artifact artifact = Artifact.patched('ios/Runner/Info.plist');

      final description = switch (artifact) {
        ScaffoldArtifact() => 'scaffold',
        ManagedArtifact() => 'managed',
        PatchedArtifact() => 'patched',
        LocalArtifact() => 'local',
      };

      expect(description, 'patched');
    });

    test('is equal to an artifact with the same class and path', () {
      expect(const Artifact.managed('lib/a'), const Artifact.managed('lib/a'));
      expect(
        const Artifact.managed('lib/a').hashCode,
        const Artifact.managed('lib/a').hashCode,
      );
      expect(
        const Artifact.managed('lib/a'),
        isNot(const Artifact.local('lib/a')),
      );
      expect(
        const Artifact.managed('lib/a'),
        isNot(const Artifact.managed('lib/b')),
      );
    });

    test('a managed artifact may declare the hash of its inputs', () {
      const artifact = Artifact.managed('a.png', inputs: 'sha256:abc');

      expect(artifact.inputs, 'sha256:abc');
      expect(const Artifact.managed('a.png').inputs, isNull);
      expect(const Artifact.patched('a.png').inputs, isNull);
    });

    test('artifacts with other inputs are other artifacts', () {
      const same = Artifact.managed('a.png', inputs: 'h1');

      expect(same, const Artifact.managed('a.png', inputs: 'h1'));
      expect(
        same.hashCode,
        const Artifact.managed('a.png', inputs: 'h1').hashCode,
      );
      expect(same, isNot(const Artifact.managed('a.png', inputs: 'h2')));
      expect(same, isNot(const Artifact.managed('a.png')));
    });

    test('describes itself with its class and path', () {
      expect(
        const Artifact.local('.idea/runConfigurations/a.xml').toString(),
        'Artifact.local(.idea/runConfigurations/a.xml)',
      );
    });
  });
}
