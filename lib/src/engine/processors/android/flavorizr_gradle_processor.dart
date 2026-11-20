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
import 'package:flutter_flavorizr/src/engine/processors/android/flavorizr_gradle_groovy_generator.dart';
import 'package:flutter_flavorizr/src/engine/processors/android/flavorizr_gradle_kotlin_generator.dart';
import 'package:flutter_flavorizr/src/exception/file_not_found_exception.dart';
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
/// `android/app/build.gradle.kts` does. The build file is a user input, so it
/// is looked up in the real project and nothing needs to copy it to the
/// workspace. The content is produced by [FlavorizrGradleGroovyGenerator] and
/// [FlavorizrGradleKotlinGenerator].
class FlavorizrGradleProcessor extends FlavorizrProcessor {
  /// Creates the processor.
  const FlavorizrGradleProcessor();

  @override
  String get id => 'android:flavorizrGradle';

  @override
  Future<void> apply(FlavorizrContext ctx) async {
    final dsl = _dslOf(ctx);

    ctx.logger.detail(
      '[$id] Found `${dsl.buildPath}`, generating `${dsl.targetPath}`',
    );

    final target = File(ctx.resolve(dsl.targetPath));

    await target.parent.create(recursive: true);
    await target.writeAsString(dsl.generate(ctx));
    ctx.track(Artifact.managed(dsl.targetPath));
  }

  static _Dsl _dslOf(FlavorizrContext ctx) {
    final candidates = [_groovy, _kotlin];

    for (final candidate in candidates) {
      if (File(ctx.resolveProject(candidate.buildPath)).existsSync()) {
        return candidate;
      }
    }

    throw FileNotFoundException(
      [for (final candidate in candidates) candidate.buildPath].toString(),
    );
  }

  static final _Dsl _groovy = _Dsl(
    buildPath: K.androidBuildLegacyPath,
    targetPath: K.androidFlavorizrLegacyPath,
    generate: (ctx) => FlavorizrGradleGroovyGenerator(
      config: ctx.config,
      logger: ctx.logger,
    ).generate(),
  );

  static final _Dsl _kotlin = _Dsl(
    buildPath: K.androidBuildKotlinPath,
    targetPath: K.androidFlavorizrKotlinPath,
    generate: (ctx) => FlavorizrGradleKotlinGenerator(
      config: ctx.config,
      logger: ctx.logger,
    ).generate(),
  );
}

/// A build script language: the build file that tells a project uses it, the
/// flavorizr file that goes with it and what generates the content of the
/// latter.
final class _Dsl {
  final String buildPath;
  final String targetPath;
  final String Function(FlavorizrContext ctx) generate;

  const _Dsl({
    required this.buildPath,
    required this.targetPath,
    required this.generate,
  });
}
