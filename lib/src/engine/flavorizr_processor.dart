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

import 'package:flutter_flavorizr/src/engine/flavorizr_context.dart';
import 'package:flutter_flavorizr/src/engine/resource_key.dart';

/// A unit of work of a flavorization run.
///
/// A processor converges part of the project to the desired state described
/// by the configuration: it is handed the whole [FlavorizrContext], writes
/// every file the desired state needs and declares what it owns through
/// [FlavorizrContext.track]. There is a single [apply] and no separate
/// `remove`: whatever is no longer desired, for example a flavor that was
/// dropped from the configuration (see [FlavorizrContext.previousFlavors]), is
/// simply not produced anymore.
///
/// Processors never touch the real project directly. They read and write
/// below [FlavorizrContext.root] and read user supplied inputs from
/// [FlavorizrContext.projectRoot]; they must never rely on the current working
/// directory.
abstract class FlavorizrProcessor {
  /// Creates a processor.
  const FlavorizrProcessor();

  /// The unique identifier of the processor, namespaced by area, e.g.
  /// `android:buildGradle`. It is the name used to request, order and report
  /// the processor.
  String get id;

  /// The ids of the processors this one needs.
  ///
  /// A dependency is pulled into the plan when it is missing, and it is
  /// applied before this processor.
  Set<String> get dependsOn => const {};

  /// The ids of the processors that, when they are part of the plan anyway,
  /// are applied before this one.
  ///
  /// Unlike [dependsOn] it only orders: it never adds a processor to the plan.
  Set<String> get after => const {};

  /// The shared resources this processor reads through
  /// [FlavorizrContext.resource].
  Set<ResourceKey<Object?>> get requires => const {};

  /// The files and folders of the project, relative to its root, that this
  /// processor reads or writes.
  ///
  /// They are what its shadow workspace is made of: nothing outside of them is
  /// copied, diffed or written back. A processor of the user declares them
  /// itself, so that registering it needs nothing but the processor.
  Set<String> get paths => const {};

  /// How to read the part of a patched file this processor owns, by path of
  /// the file.
  ///
  /// It is what the lock hashes, so that whatever else the user edits in the
  /// file is never drift. A file that is not here is hashed whole.
  Map<String, String Function(String source)> get ownedContent => const {};

  /// Converges the project to the desired state.
  ///
  /// All paths must be resolved from [FlavorizrContext.root] (output) or
  /// [FlavorizrContext.projectRoot] (user inputs). The returned future is
  /// always awaited by the engine, so everything the processor does must be
  /// completed when it resolves.
  Future<void> apply(FlavorizrContext ctx);
}
