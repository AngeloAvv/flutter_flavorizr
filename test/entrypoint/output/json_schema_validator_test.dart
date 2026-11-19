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

import 'package:test/test.dart';

import 'json_schema_validator.dart';

void main() {
  group('the validator used to hold the documents to their schema', () {
    test('accepts what the schema describes', () {
      expect(
        validateJson(
          {
            'name': 'a',
            'tags': ['x'],
            'size': 3,
          },
          {
            'type': 'object',
            'required': ['name'],
            'properties': {
              'name': {'type': 'string'},
              'tags': {
                'type': 'array',
                'items': {'type': 'string'},
              },
              'size': {'type': 'integer', 'minimum': 0},
            },
          },
        ),
        isEmpty,
      );
    });

    test('says what is wrong, and where', () {
      final errors = validateJson(
        {
          'tags': ['x', 1],
          'size': -1,
        },
        {
          'type': 'object',
          'required': ['name'],
          'properties': {
            'tags': {
              'type': 'array',
              'items': {'type': 'string'},
            },
            'size': {'type': 'integer', 'minimum': 0},
          },
        },
      );

      expect(errors, [
        r'$ has no "name"',
        r'$.tags[1] is integer, not [string]',
        r'$.size is -1, below 0',
      ]);
    });

    test('tells an integer from a number, and null from the rest', () {
      expect(validateJson(1.5, {'type': 'integer'}), isNotEmpty);
      expect(validateJson(1, {'type': 'number'}), isEmpty);
      expect(validateJson(null, {'type': 'string'}), isNotEmpty);
      expect(
        validateJson(null, {
          'type': ['string', 'null'],
        }),
        isEmpty,
      );
    });

    test('checks const and enum, null included', () {
      expect(validateJson(1, {'const': 2}), isNotEmpty);
      expect(validateJson(2, {'const': 2}), isEmpty);
      expect(
        validateJson(null, {
          'enum': ['a', null],
        }),
        isEmpty,
      );
      expect(
        validateJson('b', {
          'enum': ['a', null],
        }),
        isNotEmpty,
      );
    });

    test('follows references and allOf', () {
      final schema = <String, Object?>{
        r'$defs': {
          'positive': {'type': 'integer', 'minimum': 1},
        },
        'allOf': [
          {r'$ref': '#/\$defs/positive'},
          {'const': 0},
        ],
      };

      expect(validateJson(0, schema), hasLength(1));
      expect(validateJson(1, schema), hasLength(1));
    });

    test('takes exactly one alternative of oneOf', () {
      final schema = <String, Object?>{
        'oneOf': [
          {'type': 'integer'},
          {'type': 'number'},
        ],
      };

      expect(validateJson(1, schema), isNotEmpty);
      expect(validateJson(1.5, schema), isEmpty);
    });

    test('requires what then says only when if holds', () {
      final schema = <String, Object?>{
        'if': {
          'properties': {
            'a': {'const': 1},
          },
        },
        'then': {
          'required': ['b'],
        },
      };

      expect(validateJson({'a': 1}, schema), isNotEmpty);
      expect(validateJson({'a': 2}, schema), isEmpty);
      expect(validateJson({'a': 1, 'b': 1}, schema), isEmpty);
    });

    test('refuses what it does not know instead of ignoring it', () {
      expect(
        () => validateJson('a', {'pattern': 'a'}),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });
}
