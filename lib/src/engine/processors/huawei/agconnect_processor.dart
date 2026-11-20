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
import 'package:flutter_flavorizr/src/engine/processors/project_config_copy.dart';
import 'package:flutter_flavorizr/src/utils/constants.dart';

/// The name of the file the AppGallery Connect plugin looks for in the folder
/// of the flavor that is built.
const agconnectServicesFile = 'agconnect-services.json';

/// `huawei:agconnect`: the `agconnect-services.json` of each Android flavor that
/// has an AppGallery Connect configuration, in `android/app/src/<flavor>`.
///
/// The configuration of a flavor is an input of the user, read from the real
/// project. Its copy is [Artifact.local]: it is written again silently on every
/// run, never hashed as a file in the lock, and never a conflict or drift.
///
/// A flavor that loses its configuration, or that is removed, loses the copy
/// flavorizr made for it, as long as it still holds what flavorizr copied: see
/// [removeStaleCopies]. An `agconnect-services.json` the lock does not know, or
/// that the user changed since, is the user's and stays.
class AGConnectProcessor extends FlavorizrProcessor {
  /// Creates the processor.
  const AGConnectProcessor();

  @override
  String get id => 'huawei:agconnect';

  @override
  Future<void> apply(FlavorizrContext ctx) async {
    final copies = <String>{};

    for (final MapEntry(key: flavor, value: definition)
        in ctx.config.androidAGConnectFlavors.entries) {
      checkFlavorName(flavor);

      final destination = '${K.androidSrcPath}/$flavor/$agconnectServicesFile';

      await copyProjectConfig(
        ctx,
        source: definition.android!.agconnect!.config,
        destination: destination,
        option: 'agconnect.config',
      );
      copies.add(destination);
    }

    removeStaleCopies(
      ctx,
      keep: copies,
      isCopy: (path) => isFlavorCopyPath(
        path,
        parent: K.androidSrcPath,
        name: agconnectServicesFile,
      ),
    );
  }
}
