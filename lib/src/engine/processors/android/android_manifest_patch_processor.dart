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

import 'dart:convert';
import 'dart:io';

import 'package:flutter_flavorizr/src/engine/artifact.dart';
import 'package:flutter_flavorizr/src/engine/flavorizr_context.dart';
import 'package:flutter_flavorizr/src/engine/flavorizr_processor.dart';
import 'package:flutter_flavorizr/src/engine/processors/android/android_manifest_editor.dart';
import 'package:flutter_flavorizr/src/exception/file_not_found_exception.dart';
import 'package:flutter_flavorizr/src/utils/constants.dart';

/// Points the label of the Android application to the `app_name` resource,
/// which every flavor defines in `flavorizr.gradle(.kts)`.
///
/// The manifest belongs to the user: it is a [Artifact.patched] artifact and
/// the only part flavorizr owns is the `android:label` attribute of the
/// application (see [AndroidManifestEditor]). The rest of the file is written
/// back byte for byte, which the 2.x processor did not do since it serialized
/// the whole document again.
class AndroidManifestPatchProcessor extends FlavorizrProcessor {
  /// Creates the processor.
  const AndroidManifestPatchProcessor();

  static const List<int> _bom = [0xef, 0xbb, 0xbf];

  static bool _startsWithBom(List<int> bytes) =>
      bytes.length >= _bom.length &&
      _bom.indexed.every((entry) => bytes[entry.$1] == entry.$2);

  @override
  String get id => 'android:androidManifest';

  @override
  Future<void> apply(FlavorizrContext ctx) async {
    final file = File(ctx.resolve(K.androidManifestPath));

    if (!file.existsSync()) {
      ctx.logger.detail(
        '[$id] File not found at path `${K.androidManifestPath}`',
      );

      throw FileNotFoundException(K.androidManifestPath);
    }

    // Decoding drops a byte order mark, which has to be written back.
    final bytes = await file.readAsBytes();
    final hasBom = _startsWithBom(bytes);
    final source = utf8.decode(hasBom ? bytes.sublist(_bom.length) : bytes);
    final patched = AndroidManifestEditor.withAppLabel(source);

    if (patched != source) {
      await file.writeAsBytes([if (hasBom) ..._bom, ...utf8.encode(patched)]);
    }

    ctx.track(Artifact.patched(K.androidManifestPath));
  }
}
