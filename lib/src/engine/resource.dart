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

/// Shared state of a run, such as an opened Xcode project or downloaded
/// files, that several processors read.
///
/// A resource is not a user-visible instruction: processors list its [key] in
/// `FlavorizrProcessor.requires` and the engine drives the rest through
/// `ResourceLifecycle`. [setup] runs at most once per run, right before the
/// first processor that requires the resource, and [teardown] runs once after
/// the last one, whatever happens in between.
abstract class Resource<T> {
  /// Creates a resource.
  const Resource();

  /// The key processors use to require the resource and to read it back
  /// through [FlavorizrContext.resource].
  ResourceKey<T> get key;

  /// Creates the value shared by the consumers, e.g. opens a project or
  /// downloads files.
  ///
  /// [ctx] has no resources: a resource cannot depend on another one. When
  /// [setup] throws, no value exists and [teardown] is not called for it, so
  /// [setup] must clean up after itself before throwing.
  Future<T> setup(FlavorizrContext ctx);

  /// Releases [value], the one [setup] returned.
  ///
  /// [success] is `true` when nothing has failed in the run so far: it lets
  /// the resource persist its state only when the run went well, e.g. save
  /// the Xcode project, and discard it otherwise. It is `false` once any
  /// processor, setup or earlier teardown has failed.
  ///
  /// When [teardown] throws, the other resources are still torn down. Its
  /// error fails the run only when nothing had failed before: it never masks
  /// an earlier failure.
  Future<void> teardown(FlavorizrContext ctx, T value, {required bool success});
}
