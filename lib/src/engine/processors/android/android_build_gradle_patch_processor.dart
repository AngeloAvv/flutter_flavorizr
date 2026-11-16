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

import 'package:flutter_flavorizr/src/engine/artifact.dart';
import 'package:flutter_flavorizr/src/engine/flavorizr_context.dart';
import 'package:flutter_flavorizr/src/engine/flavorizr_processor.dart';
import 'package:flutter_flavorizr/src/engine/processors/android/android_build_gradle_editor.dart';
import 'package:flutter_flavorizr/src/engine/processors/android/bom_text_file.dart';
import 'package:flutter_flavorizr/src/engine/processors/android/flavorizr_gradle_processor.dart';
import 'package:flutter_flavorizr/src/exception/file_not_found_exception.dart';
import 'package:flutter_flavorizr/src/utils/constants.dart';

/// Makes the build file of the Android app apply the flavors file that
/// `android:flavorizrGradle` writes.
///
/// The build file belongs to the user: it is an [Artifact.patched] artifact
/// and the only part flavorizr owns is a marked region of three lines (see
/// [AndroidBuildGradleEditor]). The rest of the file is written back byte for
/// byte, and a build file that is already up to date is not written at all.
///
/// The region applies the flavors file, so it is only emitted when the
/// processor that writes that file is part of the run. [dependsOn] guarantees
/// it: the processor is pulled into the plan and applied first.
///
/// The DSL follows the build file, like in 2.x: Groovy when
/// `android/app/build.gradle` exists, otherwise Kotlin when
/// `android/app/build.gradle.kts` does. The build file is read from the
/// workspace, so the caller has to include both paths in it.
class AndroidBuildGradlePatchProcessor extends FlavorizrProcessor {
  /// Creates the processor.
  const AndroidBuildGradlePatchProcessor();

  @override
  String get id => 'android:buildGradle';

  @override
  Set<String> get dependsOn => {const FlavorizrGradleProcessor().id};

  @override
  Future<void> apply(FlavorizrContext ctx) async {
    final (path, dsl) = _buildFileOf(ctx);
    final file = File(ctx.resolve(path));

    final (:text, :hasBom) = await BomTextFile.read(file);
    final patched = AndroidBuildGradleEditor.withFlavorizrRegion(text, dsl);

    if (patched != text) {
      ctx.logger.detail('[$id] Applying `${dsl.flavorsFile}` from `$path`');

      await BomTextFile.write(file, patched, hasBom: hasBom);
    }

    ctx.track(Artifact.patched(path));
  }

  static (String, BuildGradleDsl) _buildFileOf(FlavorizrContext ctx) {
    final candidates = [
      (K.androidBuildLegacyPath, BuildGradleDsl.groovy),
      (K.androidBuildKotlinPath, BuildGradleDsl.kotlin),
    ];

    for (final candidate in candidates) {
      if (File(ctx.resolve(candidate.$1)).existsSync()) return candidate;
    }

    throw FileNotFoundException(
      [for (final (path, _) in candidates) path].toString(),
    );
  }
}
