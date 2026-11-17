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
  Future<void> run(Iterable<LegacyStep> steps, {required Logger logger});
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

    if (p.canonicalize(Directory.current.path) !=
        p.canonicalize(projectRoot.path)) {
      throw StateError(
        'The 2.x processors work on the current directory: run flavorizr from '
        'the root of the project.',
      );
    }
  }

  @override
  Future<void> run(Iterable<LegacyStep> steps, {required Logger logger}) async {
    check(steps);

    for (final step in steps) {
      await Processor(
        step.config,
        force: true,
        logger: logger,
      ).executeInstruction(step.id);
    }
  }
}
