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

import 'dart:io';

import 'package:flutter_flavorizr/src/entrypoint/legacy_pipeline.dart';
import 'package:flutter_flavorizr/src/exception/unknown_processor_exception.dart';
import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_utils.dart';
import 'cli_fixture.dart';

void main() {
  final config = Flavorizr.parse(CliFixture.config(['apple']));

  test('refuses to run on a project that is not the working directory', () {
    final elsewhere = Directory.systemTemp.createTempSync('flavorizr_legacy_');
    addTearDown(() => elsewhere.deleteSync(recursive: true));

    expect(
      () => StandardLegacyPipeline(elsewhere).run([
        LegacyStep('ide:config', config),
      ], logger: TestUtils.quietLogger()),
      throwsStateError,
    );
  });

  test('does nothing, anywhere, when there is nothing to run', () async {
    final elsewhere = Directory.systemTemp.createTempSync('flavorizr_legacy_');
    addTearDown(() => elsewhere.deleteSync(recursive: true));

    await StandardLegacyPipeline(
      elsewhere,
    ).run(const [], logger: TestUtils.quietLogger());
  });

  test('stops at the first instruction that fails', () async {
    await expectLater(
      StandardLegacyPipeline(Directory.current).run([
        LegacyStep('nope:nope', config),
        LegacyStep('ide:config', config),
      ], logger: TestUtils.quietLogger()),
      throwsA(isA<UnknownProcessorException>()),
    );
  });
}
