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

import 'package:flutter_flavorizr/src/exception/copy_back_interrupted_exception.dart';
import 'package:flutter_flavorizr/src/exception/dependency_cycle_exception.dart';
import 'package:flutter_flavorizr/src/exception/duplicate_processor_exception.dart';
import 'package:flutter_flavorizr/src/exception/invalid_recipe_name_exception.dart';
import 'package:flutter_flavorizr/src/exception/malformed_lock_file_exception.dart';
import 'package:flutter_flavorizr/src/exception/project_changed_exception.dart';
import 'package:flutter_flavorizr/src/exception/recipe_cycle_exception.dart';
import 'package:flutter_flavorizr/src/exception/unapproved_conflicts_exception.dart';
import 'package:flutter_flavorizr/src/exception/unknown_processor_exception.dart';
import 'package:flutter_flavorizr/src/exception/unknown_target_exception.dart';
import 'package:flutter_flavorizr/src/exception/unresolved_conflicts_exception.dart';
import 'package:flutter_flavorizr/src/exception/unsupported_lock_version_exception.dart';
import 'package:io/io.dart';

/// The exit codes of every command.
///
/// | Code | Meaning |
/// | --- | --- |
/// | 0 | Everything went well. |
/// | 1 | Needs attention: files edited by hand are in the way (`plan`, `apply`), the project drifted from `flavorizr.yaml` or from the lock (`status`), or a check failed (`doctor`). |
/// | 64 | The command line is wrong, e.g. an unknown target. |
/// | 65 | The configuration or the lock cannot be used. |
/// | 70 | A processor failed, or the project changed during the run. |
abstract final class ExitCodes {
  /// Everything went well.
  static final int ok = ExitCode.success.code;

  /// Something needs attention: conflicts, drift or a failed check.
  static const int attention = 1;

  /// The command line is wrong.
  static final int usage = ExitCode.usage.code;

  /// The configuration or the lock cannot be used.
  static final int data = ExitCode.data.code;

  /// A processor failed, or the project changed during the run.
  static final int software = ExitCode.software.code;

  /// The exit code that goes with [error], thrown by any step of a command, or
  /// `null` when [error] is not one the commands know how to report.
  static int? of(Object error) => switch (error) {
    UnresolvedConflictsException() ||
    UnapprovedConflictsException() => attention,
    UnknownTargetException(recipe: null) => usage,
    UnknownTargetException() ||
    InvalidRecipeNameException() ||
    RecipeCycleException() ||
    DuplicateProcessorException() ||
    UnknownProcessorException() ||
    DependencyCycleException() ||
    MalformedLockFileException() ||
    UnsupportedLockVersionException() => data,
    ProjectChangedException() || CopyBackInterruptedException() => software,
    _ => null,
  };
}
