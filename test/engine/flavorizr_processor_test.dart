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

import 'package:flutter_flavorizr/src/engine/flavorizr_context.dart';
import 'package:flutter_flavorizr/src/engine/flavorizr_processor.dart';
import 'package:flutter_flavorizr/src/engine/resource_key.dart';
import 'package:flutter_test/flutter_test.dart';

class _MinimalProcessor extends FlavorizrProcessor {
  @override
  String get id => 'test:minimal';

  @override
  Future<void> apply(FlavorizrContext ctx) async {}
}

class _DeclaringProcessor extends _MinimalProcessor {
  @override
  Set<String> get dependsOn => {'test:other'};

  @override
  Set<String> get after => {'test:earlier'};

  @override
  Set<ResourceKey<Object?>> get requires => {const ResourceKey<int>('shared')};
}

void main() {
  group('FlavorizrProcessor', () {
    test('declares no dependencies, ordering or resources by default', () {
      final processor = _MinimalProcessor();

      expect(processor.id, 'test:minimal');
      expect(processor.dependsOn, isEmpty);
      expect(processor.after, isEmpty);
      expect(processor.requires, isEmpty);
    });

    test('lets a processor declare what it depends on and requires', () {
      final processor = _DeclaringProcessor();

      expect(processor.dependsOn, {'test:other'});
      expect(processor.after, {'test:earlier'});
      expect(processor.requires, {const ResourceKey<int>('shared')});
    });
  });
}
