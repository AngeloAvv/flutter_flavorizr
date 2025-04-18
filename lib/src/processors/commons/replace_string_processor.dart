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

import 'package:flutter_flavorizr/src/processors/commons/string_processor.dart';

class ReplaceStringProcessor extends StringProcessor {
  final Pattern _find;
  final String _replace;

  ReplaceStringProcessor(
    this._find,
    this._replace, {
    super.input,
    required super.config,
    required super.logger,
  });

  @override
  String execute() {
    logger.detail(
      '[$ReplaceStringProcessor] Replacing `$_find` with `$_replace`',
    );

    final output = input!.replaceAll(_find, _replace);

    logger.detail(
      '[$ReplaceStringProcessor] Replaced `$_find` with `$_replace`',
      style: logger.theme.success,
    );

    return output;
  }

  @override
  String toString() =>
      'ReplaceStringProcessor: {find: $_find, replace: $_replace}';
}
