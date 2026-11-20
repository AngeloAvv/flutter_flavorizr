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

import 'package:flutter_flavorizr/src/engine/processors/android/gradle_value.dart';
import 'package:test/test.dart';

String groovy(Object? value) => gradleValue(value, GradleDsl.groovy);
String kotlin(Object? value) => gradleValue(value, GradleDsl.kotlin);

void main() {
  group('gradleValue', () {
    test('writes text as an escaped string literal in both languages', () {
      const text =
          r'a "b" \ $c'
          '\n\t';

      expect(groovy(text), r'"a \"b\" \\ \$c\n\t"');
      expect(kotlin(text), groovy(text));
    });

    test('writes numbers, booleans and null as they are', () {
      for (final dsl in [groovy, kotlin]) {
        expect(dsl(1000), '1000');
        expect(dsl(2.5), '2.5');
        expect(dsl(true), 'true');
        expect(dsl(null), 'null');
      }
    });

    test('writes lists and maps in the way of each language', () {
      const value = {
        'tier': 'gold',
        'levels': [1, 'two'],
      };

      expect(groovy(value), '["tier": "gold", "levels": [1, "two"]]');
      expect(
        kotlin(value),
        'mapOf("tier" to "gold", "levels" to listOf(1, "two"))',
      );
      expect(groovy(<String, Object>{}), '[:]');
      expect(kotlin(<Object>[]), 'listOf<Any>()');
      expect(kotlin(<String, Object>{}), 'mapOf<String, Any>()');
    });

    test('writes the value of a raw as it is, quotes included', () {
      const raw = {'raw': 'flavorSigning.green'};

      expect(groovy(raw), 'flavorSigning.green');
      expect(kotlin(raw), 'flavorSigning.green');
      expect(groovy({'raw': r'"$x"'}), r'"$x"');
      expect(kotlin([raw, 1]), 'listOf(flavorSigning.green, 1)');
    });

    test('is a map when raw is not the only key', () {
      expect(groovy({'raw': 'a', 'b': 1}), '["raw": "a", "b": 1]');
    });

    test('refuses what Gradle cannot be given', () {
      expect(() => groovy(DateTime(2026)), throwsArgumentError);
    });
  });

  test('gradleIsCollection tells what Groovy is given with an assignment', () {
    expect(gradleIsCollection([1]), isTrue);
    expect(gradleIsCollection({'a': 1}), isTrue);
    expect(gradleIsCollection({'raw': 'x'}), isFalse);
    expect(gradleIsCollection({'raw': 'x', 'y': 1}), isTrue);
    expect(gradleIsCollection('x'), isFalse);
    expect(gradleIsCollection(1), isFalse);
  });

  group('gradleProperty', () {
    test('assigns scalars in Kotlin and calls them in Groovy', () {
      expect(
        gradleProperty('versionCode', 3, GradleDsl.kotlin),
        'versionCode = 3',
      );
      expect(
        gradleProperty('versionCode', 3, GradleDsl.groovy),
        'versionCode 3',
      );
      expect(
        gradleProperty('signingConfig', {'raw': 'x.y'}, GradleDsl.groovy),
        'signingConfig x.y',
      );
    });

    test(
      'adds the items of a list, which the collections of a flavor take',
      () {
        expect(
          gradleProperty('resourceConfigurations', ['en'], GradleDsl.kotlin),
          'resourceConfigurations += listOf("en")',
        );
        expect(
          gradleProperty('resourceConfigurations', ['en'], GradleDsl.groovy),
          'resourceConfigurations.addAll(["en"])',
        );
      },
    );

    test('assigns a map', () {
      expect(
        gradleProperty('extras', {'a': 1}, GradleDsl.kotlin),
        'extras = mapOf("a" to 1)',
      );
      expect(
        gradleProperty('extras', {'a': 1}, GradleDsl.groovy),
        'extras = ["a": 1]',
      );
    });
  });

  test('gradleMap writes a map with the single key raw as a map', () {
    expect(
      gradleMap({'raw': 'example'}, GradleDsl.groovy),
      '["raw": "example"]',
    );
    expect(
      gradleMap({'raw': 'example'}, GradleDsl.kotlin),
      'mapOf("raw" to "example")',
    );
  });
}
