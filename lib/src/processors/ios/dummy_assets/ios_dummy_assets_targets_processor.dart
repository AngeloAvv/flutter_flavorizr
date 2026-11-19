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

import 'package:flutter_flavorizr/src/processors/commons/queue_processor.dart';

/// Used to copy a dummy `AppIcon-<flavor>.appiconset` and a dummy
/// `<flavor>LaunchImage.imageset` for each flavor.
///
/// It does nothing now: a flavor with no `icon` builds with the `AppIcon` of the
/// project (see `DarwinIconName`), an appiconset that exists is the user's, and
/// the launch image is made by `ios:launchScreen`, from the icon, for the
/// flavors that turn `launchScreen` on. The id `ios:dummyAssets` stays so that a
/// recipe that names it still runs.
class IOSDummyAssetsTargetsProcessor extends QueueProcessor {
  IOSDummyAssetsTargetsProcessor({required super.config, required super.logger})
    : super(const []);

  @override
  String toString() => 'IOSDummyAssetsTargetsProcessor';
}
