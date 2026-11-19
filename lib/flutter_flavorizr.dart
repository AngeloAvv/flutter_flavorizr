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

/// flavorizr: flavors for Flutter projects.
///
/// This library is the **stable** API: what is exported here follows semver.
///
/// * [Flavorizr] runs the command line.
/// * [FlavorizrProcessor] is a unit of work: it makes, patches or removes the
///   files of a project for the flavors of `flavorizr.yaml`.
/// * [FlavorizrContext] is what a processor is given to read the configuration
///   and to say what it owns.
/// * [Resource] and [ResourceKey] are something several processors share, such
///   as the Xcode project.
///
/// The building blocks that processors are written with, and the models of the
/// configuration, are in `package:flutter_flavorizr/experimental.dart`: they are
/// **not** covered by semver until they are promoted here.
library;

export 'src/api/flavorizr.dart' show Flavorizr;
export 'src/engine/flavorizr_context.dart' show FlavorizrContext;
export 'src/engine/flavorizr_processor.dart' show FlavorizrProcessor;
export 'src/engine/resource.dart' show Resource;
export 'src/engine/resource_key.dart' show ResourceKey;
