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

import 'dart:collection';

import 'package:flutter_flavorizr/src/parser/models/config/android.dart';
import 'package:flutter_flavorizr/src/parser/models/flavors/android/build_config_field.dart';
import 'package:flutter_flavorizr/src/parser/models/flavors/android/res_value.dart';
import 'package:flutter_flavorizr/src/processors/commons/string_processor.dart';

class AndroidFlavorizrLegacyProcessor extends StringProcessor {
  AndroidFlavorizrLegacyProcessor({
    super.input,
    required super.config,
    required super.logger,
  });

  @override
  String execute() {
    final buffer = StringBuffer();

    logger.detail('[$AndroidFlavorizrLegacyProcessor] Generating flavors in Groovy DSL');

    logger.detail('[$AndroidFlavorizrLegacyProcessor] Generating android section');
    _appendStartContent(buffer);

    logger.detail('[$AndroidFlavorizrLegacyProcessor] Generating flavor dimensions');
    _appendFlavorsDimension(buffer);

    logger.detail('[$AndroidFlavorizrLegacyProcessor] Generating flavors');
    _appendFlavors(buffer);

    logger.detail('[$AndroidFlavorizrLegacyProcessor] Generating close android section');
    _appendEndContent(buffer);

    return buffer.toString();
  }

  void _appendStartContent(StringBuffer buffer) {
    buffer.writeln('android {');
  }

  void _appendFlavorsDimension(StringBuffer buffer) {
    final flavorDimension =
        config.app?.android?.flavorDimensions ?? Android.kFlavorDimensionValue;

    buffer.writeln('    flavorDimensions += "$flavorDimension"');
    buffer.writeln();
  }

  void _appendFlavors(StringBuffer buffer) {
    final flavorDimension =
        config.app?.android?.flavorDimensions ?? Android.kFlavorDimensionValue;

    buffer.writeln('    productFlavors {');

    config.androidFlavors.forEach((name, flavor) {
      buffer.writeln('        $name {');
      buffer.writeln('            dimension "$flavorDimension"');
      buffer.writeln(
          '            applicationId "${flavor.android?.applicationId}"');

      flavor.android?.customConfig.forEach((key, value) {
        buffer.writeln('            $key $value');
      });

      final Map<String, ResValue> resValues = LinkedHashMap.from({
        'app_name': ResValue(
          type: 'string',
          value: flavor.app.name,
        )
      })
        ..addAll(config.app?.android?.resValues ?? {})
        ..addAll(flavor.android?.resValues ?? {});
      resValues.forEach((key, res) {
        buffer.writeln(
            '            resValue "${res.type}", "$key", "${res.wrappedValue}"');
      });

      final Map<String, BuildConfigField> buildConfigFields =
          LinkedHashMap.fromEntries([
        ...config.app?.android?.buildConfigFields.entries ?? [],
        ...flavor.android?.buildConfigFields.entries ?? []
      ]);
      buildConfigFields.forEach((key, res) {
        buffer.writeln(
            '            buildConfigField "${res.type}", "$key", ${res.legacyWrappedValue}');
      });

      buffer.writeln('        }');
    });

    buffer.writeln('    }');
  }

  void _appendEndContent(StringBuffer buffer) {
    buffer.write('}');
  }

  @override
  String toString() => 'AndroidFlavorizrLegacyProcessor';
}
