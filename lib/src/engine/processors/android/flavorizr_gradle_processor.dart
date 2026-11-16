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
import 'package:flutter_flavorizr/src/exception/file_not_found_exception.dart';
import 'package:flutter_flavorizr/src/processors/android/build_gradle/android_flavorizr_kotlin_processor.dart';
import 'package:flutter_flavorizr/src/processors/android/build_gradle/android_flavorizr_legacy_processor.dart';
import 'package:flutter_flavorizr/src/utils/constants.dart';

/// Writes `android/app/flavorizr.gradle(.kts)`, which declares the product
/// flavors of the project.
///
/// The file is [Artifact.managed]: it is generated whole from the
/// configuration, so a flavor that was dropped from it is not produced anymore
/// and disappears from the file on the next run, with no separate removal step.
///
/// The DSL follows the build file of the app, like in 2.x: Groovy when
/// `android/app/build.gradle` exists, otherwise Kotlin when
/// `android/app/build.gradle.kts` does. The build file is looked up in the
/// workspace, which therefore has to contain `android/app`. The content is
/// produced by the generators of the 2.x processors, which stay the single
/// source of it until they are retired.
class FlavorizrGradleProcessor extends FlavorizrProcessor {
  /// Creates the processor.
  const FlavorizrGradleProcessor();

  @override
  String get id => 'android:flavorizrGradle';

  @override
  Future<void> apply(FlavorizrContext ctx) async {
    final (buildPath, targetPath, generate) = _dsl(ctx);

    ctx.logger.detail('[$id] Found `$buildPath`, generating `$targetPath`');

    final target = File(ctx.resolve(targetPath));

    await target.create(recursive: true);
    await target.writeAsString(generate());
    ctx.track(Artifact.managed(targetPath));
  }

  /// The build file of the project, the flavorizr file that goes with it and
  /// what generates the content of the latter.
  (String, String, String Function()) _dsl(FlavorizrContext ctx) {
    final candidates = [
      (
        K.androidBuildLegacyPath,
        K.androidFlavorizrLegacyPath,
        () => AndroidFlavorizrLegacyProcessor(
          config: ctx.config,
          logger: ctx.logger,
        ).execute(),
      ),
      (
        K.androidBuildKotlinPath,
        K.androidFlavorizrKotlinPath,
        () => AndroidFlavorizrKotlinProcessor(
          config: ctx.config,
          logger: ctx.logger,
        ).execute(),
      ),
    ];

    for (final candidate in candidates) {
      if (File(ctx.resolve(candidate.$1)).existsSync()) return candidate;
    }

    throw FileNotFoundException(
      [for (final candidate in candidates) candidate.$1].toString(),
    );
  }
}
