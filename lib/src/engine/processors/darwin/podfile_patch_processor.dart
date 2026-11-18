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
import 'package:flutter_flavorizr/src/engine/processors/android/bom_text_file.dart';
import 'package:flutter_flavorizr/src/engine/processors/darwin/podfile_editor.dart';
import 'package:flutter_flavorizr/src/utils/constants.dart';

/// A processor that maps the flavors in the Podfile of a Darwin platform.
///
/// The Podfile belongs to the user: it is an [Artifact.patched] artifact and
/// the only part flavorizr owns is its marked region (see [PodfileEditor]). The
/// rest of the file is written back byte for byte, and a Podfile that is
/// already up to date is not written at all.
///
/// Like in 2.x, a project that has no Podfile is skipped: it is made by Flutter
/// or CocoaPods the first time the project is built, and flavorizr does not
/// scaffold it. The next run patches it.
abstract class PodfilePatchProcessor extends FlavorizrProcessor {
  /// Creates a processor.
  const PodfilePatchProcessor();

  /// The Podfile the processor patches, relative to the project.
  String get path;

  /// The names of the flavors of the platform in the configuration of [ctx].
  Iterable<String> flavorNames(FlavorizrContext ctx);

  @override
  Future<void> apply(FlavorizrContext ctx) async {
    final file = File(ctx.resolve(path));

    if (!file.existsSync()) {
      ctx.logger.detail('[$id] `$path` does not exist. Skipping processor.');

      return;
    }

    final (:text, :hasBom) = await BomTextFile.read(file);
    final patched = PodfileEditor.withFlavorMappings(
      text,
      flavorNames(ctx),
      path: path,
    );

    if (patched != text) {
      ctx.logger.detail('[$id] Patching `$path`');

      await BomTextFile.write(file, patched, hasBom: hasBom);
    }

    ctx.track(Artifact.patched(path));
  }
}

/// Maps the flavors of iOS in `ios/Podfile`.
class IosPodfilePatchProcessor extends PodfilePatchProcessor {
  /// Creates the processor.
  const IosPodfilePatchProcessor();

  @override
  String get id => 'ios:podfile';

  @override
  String get path => K.iOSPodfilePath;

  @override
  Iterable<String> flavorNames(FlavorizrContext ctx) =>
      ctx.config.iosFlavors.keys;
}

/// Maps the flavors of macOS in `macos/Podfile`.
class MacosPodfilePatchProcessor extends PodfilePatchProcessor {
  /// Creates the processor.
  const MacosPodfilePatchProcessor();

  @override
  String get id => 'macos:podfile';

  @override
  String get path => K.macOSPodfilePath;

  @override
  Iterable<String> flavorNames(FlavorizrContext ctx) =>
      ctx.config.macosFlavors.keys;
}
