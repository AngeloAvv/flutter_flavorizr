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

import 'package:flutter_flavorizr/src/engine/flavorizr_processor.dart';
import 'package:flutter_flavorizr/src/entrypoint/run.dart';

/// The entry point of flavorizr, for the command line of a project.
///
/// `dart run flutter_flavorizr` is this, with the arguments it was given. A
/// project that has its own processors calls it from `tool/flavorizr.dart`,
/// which `dart run flutter_flavorizr` runs instead of its own entry point:
///
/// ```dart
/// import 'package:flutter_flavorizr/flutter_flavorizr.dart';
///
/// void main(List<String> args) =>
///     Flavorizr.run(args, processors: [SentryProcessor()]);
/// ```
abstract final class Flavorizr {
  /// Runs the command named by [args] (`plan`, `apply`, `status`, `list`,
  /// `doctor`; `apply` when there is none) and ends the process with its exit
  /// code when that is not `0`. See https://docs.page/AngeloAvv/flutter_flavorizr/reference/cli for the commands, the options
  /// and the exit codes.
  ///
  /// The [processors] are the ones of the project, which run along with the
  /// ones of flavorizr: their ids can be used in the recipes of
  /// `flavorizr.yaml` and as targets. An id that is already taken is an error,
  /// and so is one in a namespace of flavorizr (`android`, `ios`, `macos`,
  /// `linux`, `windows`, `flutter`, `google`, `huawei` and `ide`).
  ///
  /// The [overrides] replace a processor of flavorizr, the one that has their
  /// id, which is the only way to take one: replacing `flutter:app` is how the
  /// Flutter code that is generated is customized. An override takes the place
  /// of the processor in the recipes, and works on the paths of the processor
  /// it replaces as well as on its own (when that one is on the engine). An id that flavorizr does not have is
  /// an error. `flavorizr list` tells which processors are overridden.
  static Future<void> run(
    List<String> args, {
    Iterable<FlavorizrProcessor> processors = const [],
    Iterable<FlavorizrProcessor> overrides = const [],
  }) => execute(args, processors: processors, overrides: overrides);
}
