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

import 'package:flutter_flavorizr/src/engine/artifact.dart';
import 'package:flutter_flavorizr/src/engine/flavorizr_context.dart';
import 'package:flutter_flavorizr/src/engine/flavorizr_processor.dart';
import 'package:flutter_flavorizr/src/engine/processors/android/bom_text_file.dart';
import 'package:flutter_flavorizr/src/engine/processors/darwin/info_plist_editor.dart';
import 'package:flutter_flavorizr/src/exception/file_not_found_exception.dart';
import 'package:flutter_flavorizr/src/utils/constants.dart';

/// A processor that points the bundle keys of the `Info.plist` of a Darwin
/// platform to the values every flavor defines in its xcconfig.
///
/// The plist belongs to the user: it is an [Artifact.patched] artifact and the
/// only part flavorizr owns is the value of the keys it sets (see
/// [InfoPlistEditor]). The rest of the file is written back byte for byte, which
/// the 2.x processor did not do since it serialized the whole document again,
/// and a plist that is already up to date is not written at all.
abstract class InfoPlistPatchProcessor extends FlavorizrProcessor {
  /// Creates a processor.
  const InfoPlistPatchProcessor();

  /// The plist the processor patches, relative to the project.
  String get path;

  /// The strings of the plist the processor sets, by key.
  Map<String, String> values(FlavorizrContext ctx);

  @override
  Future<void> apply(FlavorizrContext ctx) async {
    final file = File(ctx.resolve(path));

    if (!file.existsSync()) {
      ctx.logger.detail('[$id] File not found at path `$path`');

      throw FileNotFoundException(path);
    }

    final (:text, :hasBom) = await BomTextFile.read(file);
    final patched = InfoPlistEditor.withStrings(text, values(ctx));

    if (patched != text) {
      ctx.logger.detail('[$id] Patching `$path`');

      await BomTextFile.write(file, patched, hasBom: hasBom);
    }

    ctx.track(Artifact.patched(path));
  }
}

/// Sets the name, the display name and, when the launch screen is one of the
/// processors of the run (`ios:launchScreen`, on the legacy pipeline), the launch storyboard of `ios/Runner/Info.plist`.
class IosInfoPlistPatchProcessor extends InfoPlistPatchProcessor {
  /// Creates the processor.
  const IosInfoPlistPatchProcessor();

  @override
  String get id => 'ios:plist';

  @override
  String get path => K.iOSPListPath;

  @override
  Map<String, String> values(FlavorizrContext ctx) => {
    InfoPlistEditor.bundleName: InfoPlistEditor.bundleNameValue,
    InfoPlistEditor.bundleDisplayName: InfoPlistEditor.bundleDisplayNameValue,
    if (ctx.selected.contains('ios:launchScreen'))
      InfoPlistEditor.launchStoryboardName:
          InfoPlistEditor.launchStoryboardNameValue,
  };
}

/// Sets the name of `macos/Runner/Info.plist`.
class MacosInfoPlistPatchProcessor extends InfoPlistPatchProcessor {
  /// Creates the processor.
  const MacosInfoPlistPatchProcessor();

  @override
  String get id => 'macos:plist';

  @override
  String get path => K.macOSPlistPath;

  @override
  Map<String, String> values(FlavorizrContext ctx) => {
    InfoPlistEditor.bundleName: InfoPlistEditor.bundleNameValue,
  };
}
