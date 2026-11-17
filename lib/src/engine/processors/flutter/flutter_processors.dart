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
import 'package:flutter_flavorizr/src/engine/processors/flutter/flutter_sources.dart';
import 'package:flutter_flavorizr/src/utils/constants.dart';

/// Writes [content] to the path of [artifact] in the workspace and declares it.
Future<void> _write(
  FlavorizrContext ctx,
  Artifact artifact,
  String content,
) async {
  final target = File(ctx.resolve(artifact.path));

  await target.parent.create(recursive: true);
  await target.writeAsString(content);
  ctx.track(artifact);
}

/// Writes the Dart side of the flavors: `lib/flavors.g.dart`, which holds the
/// `Flavor` enum and `F`, and `lib/flavors.dart`, which exports it.
///
/// * `flavors.g.dart` is [Artifact.managed]: it is generated whole from the
///   configuration, so it is hashed in the lock, a flavor that was dropped
///   disappears from it, and a hand edit of it is a conflict.
/// * `flavors.dart` is [Artifact.scaffold]: the user's, who is meant to extend
///   it. It is created when the project has none and never written again, so
///   2.x projects, whose `flavors.dart` holds the enum, keep theirs untouched.
///
/// `F.appFlavor` reads the flavor from `appFlavor` of
/// `package:flutter/services.dart`, so nothing has to initialize it (2.x did, in
/// the `main` it overwrote), and it throws an error that says how to fix it when
/// the app was built without one.
class FlutterFlavorsProcessor extends FlavorizrProcessor {
  /// Creates the processor.
  const FlutterFlavorsProcessor();

  @override
  String get id => 'flutter:flavors';

  @override
  Future<void> apply(FlavorizrContext ctx) async {
    ctx.logger.detail('[$id] Generating `${K.flutterFlavorsGeneratedPath}`');

    _warnAboutOldFlavors(ctx);

    await _write(
      ctx,
      Artifact.managed(K.flutterFlavorsGeneratedPath),
      flavorsGeneratedSource(ctx.config),
    );
    await _write(
      ctx,
      Artifact.scaffold(K.flutterFlavorPath),
      flavorsScaffoldSource,
    );
  }

  /// A `flavors.dart` of the user that does not export `flavors.g.dart` is the
  /// one 2.x generated, with its own `Flavor` and `F`: it is left alone, so the
  /// code is not the one `flavors.g.dart` has, and it is not kept up to date.
  void _warnAboutOldFlavors(FlavorizrContext ctx) {
    final file = File(ctx.resolveProject(K.flutterFlavorPath));

    if (file.existsSync() &&
        !file.readAsStringSync().contains('flavors.g.dart')) {
      ctx.logger.warn(
        '[$id] `${K.flutterFlavorPath}` does not export '
        '`flavors.g.dart`, so it does not follow the flavors of '
        'flavorizr.yaml anymore (flavorizr never overwrites it). If 2.x '
        'generated it, delete it and run flavorizr again.',
      );
    }
  }
}

/// Writes one starting file of a new app, which is the user's from then on:
/// [Artifact.scaffold], so a file that exists is never overwritten.
abstract class _FlutterScaffoldProcessor extends FlavorizrProcessor {
  const _FlutterScaffoldProcessor();

  /// The path of the file, relative to the project.
  String get path;

  /// What the file holds when it is created.
  String get source;

  @override
  Future<void> apply(FlavorizrContext ctx) async {
    ctx.logger.detail('[$id] Scaffolding `$path`');

    await _write(ctx, Artifact.scaffold(path), source);
  }
}

/// Scaffolds `lib/app.dart`: the `MaterialApp` titled by the flavor, with a
/// banner that names it in debug.
///
/// It needs the flavors and the page it opens.
class FlutterAppProcessor extends _FlutterScaffoldProcessor {
  /// Creates the processor.
  const FlutterAppProcessor();

  @override
  String get id => 'flutter:app';

  @override
  Set<String> get dependsOn => const {'flutter:flavors', 'flutter:pages'};

  @override
  String get path => K.flutterAppPath;

  @override
  String get source => appScaffoldSource;
}

/// Scaffolds `lib/pages/my_home_page.dart`, the page the app opens.
class FlutterPagesProcessor extends _FlutterScaffoldProcessor {
  /// Creates the processor.
  const FlutterPagesProcessor();

  @override
  String get id => 'flutter:pages';

  @override
  Set<String> get dependsOn => const {'flutter:flavors'};

  @override
  String get path => K.flutterMainPagePath;

  @override
  String get source => homePageScaffoldSource;
}

/// Scaffolds `lib/main.dart`, which just runs the app: it initializes nothing,
/// since `F.appFlavor` reads the flavor by itself.
class FlutterMainProcessor extends _FlutterScaffoldProcessor {
  /// Creates the processor.
  const FlutterMainProcessor();

  @override
  String get id => 'flutter:main';

  @override
  Set<String> get dependsOn => const {'flutter:app'};

  @override
  String get path => K.flutterMainPath;

  @override
  String get source => mainScaffoldSource;
}
