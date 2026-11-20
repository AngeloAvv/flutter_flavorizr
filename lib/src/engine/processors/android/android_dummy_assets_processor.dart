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
import 'package:flutter_flavorizr/src/engine/flavorizr_processor.dart';

/// `android:dummyAssets`: it makes nothing.
///
/// 2.x copied a dummy launcher icon into the source set of each flavor. 3.0
/// does not: a flavor with no `icon` has no source set of its own, so it uses
/// the `res` of `main`, which is the default icon of the project, and the icons
/// that exist in a source set are the user's or the ones of `android:icons`.
/// What a project still has of the placeholders is recognised by hash, when it
/// is adopted (see `DummyAssets`), and removed by `android:icons` like any icon
/// it does not make anymore.
///
/// The id stays so that a recipe that names it still runs, and so that
/// `android:icons` is ordered after it, as it always was.
class AndroidDummyAssetsProcessor extends FlavorizrProcessor {
  /// Creates the processor.
  const AndroidDummyAssetsProcessor();

  @override
  String get id => 'android:dummyAssets';

  @override
  Future<void> apply(FlavorizrContext ctx) async {}
}
