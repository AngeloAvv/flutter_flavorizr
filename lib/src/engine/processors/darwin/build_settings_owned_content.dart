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

import 'package:flutter_flavorizr/src/engine/darwin/owned_build_settings.dart';

/// The part of a `project.pbxproj` the build settings of the flavors make up,
/// which is what the lock hashes for `ios:buildTargets` and
/// `macos:buildTargets`:
///
/// * every setting of the configurations `<Mode>-<flavor>` of the **project**
///   (`Debug-dev`, `Profile-dev`, `Release-dev`), which flavorizr makes from the
///   settings of the yaml, and
/// * `PRODUCT_NAME` of the configurations of the **first native target** with
///   the same names. Nothing else of the target: `DEVELOPMENT_TEAM` and the
///   rest of what Xcode writes there is the user's, and never drift.
///
/// So a change of the yaml shows (the project is written), and so does an edit
/// by hand of what flavorizr wrote, which the run would write over: that is a
/// conflict, which the user resolves. The settings of the other configurations
/// (`Debug`, `Release`, `Profile`, the ones of the other targets) are not in it.
///
/// It is made to be read from the text of the file, by what the objects refer
/// to, never by the annotations of a line: the project is the one a
/// `PBXProject` object says, and the first target the first of its `targets`.
/// A text that is not a project is empty.
///
/// A setting a user adds by hand to a configuration of the project that is
/// named like a flavor one is taken for one of flavorizr's: it is part of the
/// content, so it is a conflict when a run also changes the settings of the
/// flavors. The write is the user's to approve, and keeps the setting.
String buildSettingsOwnedContent(String source) {
  final objects = _objects(source);
  final project = objects.values.firstWhere(
    (object) => object.isa == 'PBXProject',
    orElse: () => _Object.empty,
  );
  final firstTarget = objects[project.firstOf('targets')];
  final owned = <String>[];

  void collect(String scope, String? list, {String? only}) {
    for (final uuid
        in objects[list]?.listOf('buildConfigurations') ?? const []) {
      final config = objects[uuid];
      final name = config?.name;

      if (config == null ||
          name == null ||
          !_flavorConfiguration.hasMatch(name)) {
        continue;
      }

      for (final entry in config.settings.entries) {
        if (only == null || entry.key == only) {
          owned.add(
            '${OwnedBuildSettings.keyOf(scope, name, entry.key)} = ${entry.value}',
          );
        }
      }
    }
  }

  collect(
    OwnedBuildSettings.projectScope,
    project.reference('buildConfigurationList'),
  );
  collect(
    OwnedBuildSettings.targetScope,
    firstTarget?.reference('buildConfigurationList'),
    only: 'PRODUCT_NAME',
  );

  return owned.join('\n');
}

/// The name of the build configuration of a flavor: the mode and the flavor.
final _flavorConfiguration = RegExp(r'^(?:Debug|Profile|Release)-.+$');

final _definition = RegExp(
  r'^\t\t([0-9A-F]{24}(?:[0-9A-F]{8})?)(?: /\*.*?\*/)? = \{\s*$',
);
final _isa = RegExp(r'^\t\t\tisa = (\w+);\s*$');
final _attribute = RegExp(
  r'^\t\t\t(\w+) = ([0-9A-F]{24}(?:[0-9A-F]{8})?)(?: /\*.*?\*/)?;\s*$',
);
final _listStart = RegExp(r'^\t\t\t(\w+) = \(\s*$');
final _listItem = RegExp(
  r'^\t\t\t\t([0-9A-F]{24}(?:[0-9A-F]{8})?)(?: /\*.*?\*/)?,\s*$',
);
final _name = RegExp(r'^\t\t\tname = (?:"((?:[^"\\]|\\.)*)"|([^;"\s]+));\s*$');
final _settingsStart = RegExp(r'^\t\t\tbuildSettings = \{\s*$');
final _setting = RegExp(r'^\t\t\t\t("(?:[^"\\]|\\.)*"|[^\s=;"]+) = ');

/// The multi-line objects of the file, by UUID.
Map<String, _Object> _objects(String source) {
  final objects = <String, _Object>{};
  final lines = source.split(RegExp(r'\r?\n'));
  String? uuid;
  var body = <String>[];

  for (final line in lines) {
    if (uuid == null) {
      uuid = _definition.firstMatch(line)?.group(1);
      body = [];

      continue;
    }

    if (line == '\t\t};') {
      objects[uuid] = _Object(body);
      uuid = null;

      continue;
    }

    body.add(line);
  }

  return objects;
}

/// An object of the project, as the lines of its body.
final class _Object {
  static final empty = _Object(const []);

  final List<String> lines;

  _Object(this.lines);

  String? get isa => _first(_isa);

  String? get name {
    for (final line in lines) {
      final match = _name.firstMatch(line);

      if (match != null) return match.group(1) ?? match.group(2);
    }

    return null;
  }

  /// The UUID an attribute such as `buildConfigurationList` refers to.
  String? reference(String attribute) {
    for (final line in lines) {
      final match = _attribute.firstMatch(line);

      if (match != null && match.group(1) == attribute) return match.group(2);
    }

    return null;
  }

  /// The UUIDs of a list attribute such as `targets`.
  List<String> listOf(String attribute) {
    final items = <String>[];
    var inside = false;

    for (final line in lines) {
      if (!inside) {
        inside = _listStart.firstMatch(line)?.group(1) == attribute;
      } else if (line == '\t\t\t);') {
        break;
      } else if (_listItem.firstMatch(line) case final match?) {
        items.add(match.group(1)!);
      }
    }

    return items;
  }

  String? firstOf(String attribute) => listOf(attribute).firstOrNull;

  /// The build settings, by setting as the file spells it, with the lines of the
  /// entry (a list takes several).
  Map<String, String> get settings {
    final entries = <String, String>{};
    var inside = false;
    String? key;
    var value = <String>[];

    void flush() {
      if (key != null) entries[key!] = value.join('\n');
      key = null;
      value = [];
    }

    for (final line in lines) {
      if (!inside) {
        inside = _settingsStart.hasMatch(line);

        continue;
      }

      if (line == '\t\t\t};') {
        flush();

        break;
      }

      if (_setting.firstMatch(line) case final match?) {
        flush();
        key = match.group(1)!;
        value.add(line.substring(match.end));
      } else {
        value.add(line);
      }
    }

    return Map.fromEntries(
      entries.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
  }

  String? _first(RegExp pattern) {
    for (final line in lines) {
      final match = pattern.firstMatch(line);

      if (match != null) return match.group(1);
    }

    return null;
  }
}
