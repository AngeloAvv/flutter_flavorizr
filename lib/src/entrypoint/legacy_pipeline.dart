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

import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:flutter_flavorizr/src/processors/processor.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

/// One 2.x instruction to run, with the configuration to run it with.
final class LegacyStep {
  /// The id of the instruction, e.g. `flutter:flavors`.
  final String id;

  /// The configuration the instruction reads.
  final Flavorizr config;

  /// Creates a step.
  const LegacyStep(this.id, this.config);
}

/// What runs the processors that are not on the engine yet.
///
/// They are the 2.x processors: they write straight to the project, which is
/// the working directory, with no preview, no conflict detection and no lock.
/// The pipeline goes away with the last of them.
abstract interface class LegacyPipeline {
  /// Throws when [steps] cannot run, so that a command finds out before it
  /// writes anything.
  void check(Iterable<LegacyStep> steps);

  /// Runs [steps] in order. The first one that throws aborts the run.
  ///
  /// [preserve] are paths of the project, relative to it, that the engine
  /// generated: whatever a step does to them is undone, so that a 2.x processor
  /// never overwrites what the engine owns.
  Future<void> run(
    Iterable<LegacyStep> steps, {
    required Logger logger,
    Set<String> preserve = const {},
  });
}

/// The pipeline of the 2.x processors.
class StandardLegacyPipeline implements LegacyPipeline {
  /// The project the processors run on. It must be the working directory, which
  /// is where the 2.x processors look for their files.
  final Directory projectRoot;

  /// Creates the pipeline of the project in [projectRoot].
  const StandardLegacyPipeline(this.projectRoot);

  @override
  void check(Iterable<LegacyStep> steps) {
    if (steps.isEmpty) return;

    // The same folder may be reached through links, such as /tmp on macOS.
    if (Directory.current.resolveSymbolicLinksSync() !=
        projectRoot.resolveSymbolicLinksSync()) {
      throw StateError(
        'The 2.x processors work on the current directory: run flavorizr from '
        'the root of the project.',
      );
    }
  }

  @override
  Future<void> run(
    Iterable<LegacyStep> steps, {
    required Logger logger,
    Set<String> preserve = const {},
  }) async {
    check(steps);

    for (final step in steps) {
      // A step may copy a whole folder over files of the engine, such as the
      // placeholders of `android:dummyAssets` over the icons: the folder is
      // copied as it always was, and these files are put back.
      final kept = {
        for (final path in preserve)
          if (File(p.join(projectRoot.path, path)).existsSync())
            path: File(p.join(projectRoot.path, path)).readAsBytesSync(),
      };

      try {
        await Processor(
          step.config,
          force: true,
          logger: logger,
        ).executeInstruction(step.id);
      } finally {
        for (final MapEntry(:key, :value) in kept.entries) {
          final file = File(p.join(projectRoot.path, key));

          // Only what the step changed: a file it left alone may well be one
          // that cannot be written.
          if (!file.existsSync() || !_same(file.readAsBytesSync(), value)) {
            file.writeAsBytesSync(value);
          }
        }
      }
    }
  }
}

bool _same(List<int> a, List<int> b) =>
    a.length == b.length &&
    Iterable.generate(a.length).every((i) => a[i] == b[i]);
