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

import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:dart_xcodeproj/dart_xcodeproj.dart';
import 'package:flutter_flavorizr/src/engine/darwin/owned_objects.dart';
import 'package:flutter_flavorizr/src/engine/shadow/file_digest.dart';

/// The build settings of the configurations of a flavor, edited **key by key**
/// instead of being replaced.
///
/// 2.x set the `buildSettings` of a configuration as a whole on every run,
/// which wiped whatever the user (or Xcode) had put there: the
/// `DEVELOPMENT_TEAM` chosen in Signing & Capabilities (#340). Here flavorizr
/// owns **the keys it sets and nothing else**:
///
/// * [apply] sets the keys that are wanted, leaving every other key of the
///   configuration as it is, and
/// * the lock records, for each key, the hash of the value flavorizr wrote
///   (`FlavorizrContext.ownKeys`, `keys` in `flavorizr.lock`).
/// * [settle] removes a key that was recorded and is not wanted anymore (it
///   left the yaml, or its flavor did) **only when its value is still the one
///   flavorizr wrote**. A value somebody changed is theirs now: it is left and
///   forgotten.
///
/// A key of the lock is `<scope>/<configuration>/<setting>`, such as
/// `project/Debug-dev/SWIFT_VERSION` or `target/Debug-dev/PRODUCT_NAME`: the
/// [projectScope] configurations are the ones of the project, the [targetScope]
/// ones the ones of its first native target.
///
/// What it does **not** do is tell a hand edit of an owned key from a change
/// of the yaml: the value it sets replaces the one in the project. A hand edit
/// is caught by the lock, which hashes the owned build settings in
/// `project.pbxproj` (see `buildSettingsOwnedContent`) and so makes the edit a
/// conflict for the user to resolve, before the project is written.
///
/// One instance per processor and project, for one `FlavorizrProcessor.apply`.
final class OwnedBuildSettings {
  /// The scope of the configurations of the project.
  static const projectScope = 'project';

  /// The scope of the configurations of the first native target.
  static const targetScope = 'target';

  final OwnedObjects _owned;
  final Map<String, String> _previous;
  final Map<String, String> _written = {};

  /// Edits the settings of the configurations of the project of [owned], which
  /// remembers what the lock recorded for its processor in the same file.
  OwnedBuildSettings(this._owned)
    : _previous = _owned.ctx.previousKeysOf(_owned.artifact.path);

  /// The hash the lock keeps of the [value] of a setting.
  static String hashOf(Object? value) =>
      digestOf(utf8.encode(jsonEncode(value)));

  /// The name the lock gives to the [setting] of the configuration [name] of a
  /// [scope].
  static String keyOf(String scope, String name, String setting) =>
      '$scope/$name/$setting';

  /// Sets the settings of [wanted] in [config], one by one, and owns them.
  ///
  /// The other settings of [config] are not touched. The values are copied: a
  /// list is never shared between two configurations.
  void apply(
    XCBuildConfiguration config, {
    required String scope,
    required Map<String, dynamic> wanted,
  }) {
    final name = config.name;

    if (name == null) {
      throw StateError('The build configuration ${config.uuid} has no name.');
    }

    final settings = Map<String, dynamic>.of(config.buildSettings);

    for (final MapEntry(key: setting, value: value) in wanted.entries) {
      settings[setting] = _copy(value);
      _written[keyOf(scope, name, setting)] = hashOf(value);
    }

    config.buildSettings = settings;
  }

  /// Ends the run on the settings: removes the ones the lock recorded that
  /// [apply] was not asked to set and still hold what flavorizr wrote, and
  /// tells the context what it owns now. Returns the keys it removed, sorted.
  ///
  /// Call it once, after the last [apply]. A setting of a configuration that
  /// is no longer in the project is just forgotten, and so is a key the lock
  /// holds that is not the name of a setting of a configuration.
  List<String> settle() {
    final project = _owned.project;
    final removed = <String>[];

    for (final MapEntry(key: key, value: hash) in _previous.entries.sorted(
      (a, b) => a.key.compareTo(b.key),
    )) {
      if (_written.containsKey(key)) continue;

      final parts = _parse(key);

      if (parts == null) continue;

      final (scope, name, setting) = parts;
      final list = switch (scope) {
        projectScope => project.buildConfigurationList,
        targetScope =>
          project.nativeTargets.firstOrNull?.buildConfigurationList,
        _ => null,
      };
      final config = list?[name];

      if (config == null ||
          !config.buildSettings.containsKey(setting) ||
          hashOf(config.buildSettings[setting]) != hash) {
        continue;
      }

      config.buildSettings = Map.of(config.buildSettings)..remove(setting);
      removed.add(key);
    }

    _owned.ctx.ownKeys(_owned.artifact.path, _written);

    return removed;
  }

  /// `scope/configuration/setting`: the configuration is what is between the
  /// first two `/` (a flavor is never named with one), and the setting is
  /// everything after.
  static (String, String, String)? _parse(String key) {
    final first = key.indexOf('/');
    final second = first < 0 ? -1 : key.indexOf('/', first + 1);

    if (second < 0) return null;

    return (
      key.substring(0, first),
      key.substring(first + 1, second),
      key.substring(second + 1),
    );
  }

  static Object? _copy(Object? value) => switch (value) {
    Map() => {for (final entry in value.entries) entry.key: _copy(entry.value)},
    List() => [for (final item in value) _copy(item)],
    _ => value,
  };
}
