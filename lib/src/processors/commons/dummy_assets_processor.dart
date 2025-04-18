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

import 'package:flutter_flavorizr/src/parser/models/flavors/commons/os.dart';
import 'package:flutter_flavorizr/src/processors/commons/copy_folder_processor.dart';

class DummyAssetsProcessor extends CopyFolderProcessor {
  final OS _os;

  DummyAssetsProcessor(
    super.source,
    super.destination,
    this._os, {
    required super.config,
    required super.logger,
  });

  @override
  void execute() {
    if (_os.generateDummyAssets) {
      logger.detail(
        '[$DummyAssetsProcessor] Generating dummy assets into `$destination`',
      );

      super.execute();

      logger.detail(
        '[$DummyAssetsProcessor] Dummy assets generated into `$destination`',
        style: logger.theme.success,
      );
    }

    logger.detail(
      '[$DummyAssetsProcessor] Skipping dummy assets generation',
      style: logger.theme.warn,
    );
  }

  @override
  String toString() =>
      'DummyAssetProcessor: { source: $source, destination: $destination }';
}
