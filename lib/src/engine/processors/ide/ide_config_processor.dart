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

import 'dart:convert';
import 'dart:io';

import 'package:flutter_flavorizr/src/engine/artifact.dart';
import 'package:flutter_flavorizr/src/engine/flavorizr_context.dart';
import 'package:flutter_flavorizr/src/engine/flavorizr_processor.dart';
import 'package:flutter_flavorizr/src/engine/processors/ide/vscode_launch_editor.dart';
import 'package:flutter_flavorizr/src/extensions/extensions_string.dart';
import 'package:flutter_flavorizr/src/parser/models/enums.dart';
import 'package:flutter_flavorizr/src/parser/models/flavors/darwin/enums.dart';
import 'package:flutter_flavorizr/src/utils/constants.dart';
import 'package:xml/xml.dart';

/// Writes the run configurations of the flavors for the IDEs of `ide`:
/// `.idea/runConfigurations/<flavor>.xml` for IntelliJ and Android Studio, and
/// the entries of `.vscode/launch.json` for VS Code.
///
/// Both are [Artifact.local]: the IDEs write to them and git ignores `.idea/`,
/// so they are regenerated silently on every run, never hashed in the lock, and
/// never a conflict or drift. A fresh clone, which has no `.idea/`, is in sync.
///
/// * Each flavor has its own file in `.idea/runConfigurations`, which is
///   written again whole. The file of a flavor that was dropped is removed.
/// * In `launch.json` only the entries named after a flavor (`<flavor> Debug`,
///   `<flavor> Profile` and `<flavor> Release`) are added, replaced or, for a
///   flavor that was dropped, removed. The file is JSONC: the comments and the
///   entries of the user are kept as they are. A file that cannot be read is
///   left alone with a warning that says which entries to add by hand.
class IdeConfigProcessor extends FlavorizrProcessor {
  /// Creates the processor.
  const IdeConfigProcessor();

  @override
  String get id => 'ide:config';

  @override
  Future<void> apply(FlavorizrContext ctx) async {
    for (final ide in {...?ctx.config.ide}) {
      switch (ide) {
        case IDE.idea:
          _idea(ctx);
        case IDE.vscode:
          _vscode(ctx);
      }
    }
  }

  /// The flavors of an earlier run that the configuration no longer has.
  Set<String> _dropped(FlavorizrContext ctx) =>
      ctx.previousFlavors.difference(ctx.desiredFlavors.keys.toSet());

  void _idea(FlavorizrContext ctx) {
    ctx.logger.detail('[$id] Writing the run configurations of IntelliJ');

    for (final flavor in ctx.desiredFlavors.keys) {
      final path = _ideaPath(flavor);
      final file = File(ctx.resolve(path));

      file.parent.createSync(recursive: true);
      file.writeAsStringSync(_ideaRunConfiguration(flavor));
      ctx.track(Artifact.local(path));
    }

    for (final flavor in _dropped(ctx)) {
      if (!_isFileName(flavor)) continue;

      final path = _ideaPath(flavor);
      final file = File(ctx.resolve(path));

      if (file.existsSync()) {
        file.deleteSync();
        ctx.track(Artifact.local(path));
      }
    }
  }

  void _vscode(FlavorizrContext ctx) {
    ctx.logger.detail('[$id] Writing the launch configurations of VS Code');

    final entries = [
      for (final flavor in ctx.desiredFlavors.keys)
        for (final target in Target.values) _vscodeEntry(flavor, target),
    ];
    final file = File(ctx.resolve(K.vsCodeLaunchPath));

    if (!file.existsSync()) {
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(VsCodeLaunchEditor.create(entries));
      ctx.track(Artifact.local(K.vsCodeLaunchPath));

      return;
    }

    try {
      final edited = VsCodeLaunchEditor.edit(
        file.readAsStringSync(),
        entries,
        remove: {
          for (final flavor in _dropped(ctx))
            for (final target in Target.values) _vscodeName(flavor, target),
        },
      );

      file.writeAsStringSync(edited);
      ctx.track(Artifact.local(K.vsCodeLaunchPath));
    } on FormatException catch (error) {
      ctx.logger.warn(
        '[$id] `${K.vsCodeLaunchPath}` was left as it is: it cannot be read '
        '(${error.message}). Add these entries to its `configurations`:\n'
        '${const JsonEncoder.withIndent('  ').convert(entries)}',
      );
    }
  }

  static String _ideaPath(String flavor) => '${K.ideaLaunchpath}/$flavor.xml';

  static bool _isFileName(String flavor) =>
      flavor.isNotEmpty &&
      flavor != '.' &&
      flavor != '..' &&
      !flavor.contains(RegExp(r'[/\\\x00]'));

  static String _vscodeName(String flavor, Target target) =>
      '$flavor ${target.name.capitalize}';

  static Map<String, Object?> _vscodeEntry(String flavor, Target target) => {
    'name': _vscodeName(flavor, target),
    'request': 'launch',
    'type': 'dart',
    'flutterMode': target.name.toLowerCase(),
    'args': ['--flavor', flavor],
    'program': 'lib/main.dart',
  };

  static String _ideaRunConfiguration(String flavor) {
    if (!_isFileName(flavor)) {
      throw ArgumentError.value(
        flavor,
        'flavor',
        'cannot be used as the name of a file',
      );
    }

    final builder = XmlBuilder();

    builder.element(
      'component',
      attributes: {'name': 'ProjectRunConfigurationManager'},
      nest: () {
        builder.element(
          'configuration',
          attributes: {
            'default': 'false',
            'name': flavor,
            'type': 'FlutterRunConfigurationType',
            'factoryName': 'Flutter',
          },
          nest: () {
            builder.element(
              'option',
              attributes: {'name': 'buildFlavor', 'value': flavor},
            );
            builder.element(
              'option',
              attributes: {
                'name': 'filePath',
                'value': r'$PROJECT_DIR$/lib/main.dart',
              },
            );
            builder.element('method', attributes: {'v': '2'});
          },
        );
      },
    );

    return builder.buildDocument().toXmlString(pretty: true);
  }
}
