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
/// A key of the lock is `<scope>/<configuration UUID>/<setting>`, such as
/// `project/C93DD37D645EA448590670D3/SWIFT_VERSION`: the [projectScope]
/// configurations are the ones of the project, the [targetScope] ones the ones
/// of its first native target. The configuration is told by its UUID, which no
/// other configuration of the project has, and not by its name, which every
/// target has.
///
/// The value is hashed **as the project stores it**: `dart_xcodeproj` writes a
/// flag string such as `-ObjC -all_load` as a list in the settings that Xcode
/// keeps as lists (`OTHER_LDFLAGS`), and reads it back as one. What is hashed,
/// when it is written and when it is looked for again, is that form.
///
/// Two things tell a hand edit from a change of the yaml. The lock hashes the
/// owned build settings in `project.pbxproj` (see `buildSettingsOwnedContent`),
/// and [apply] compares the value it finds with the hash it recorded, and
/// reports the file as edited (`FlavorizrContext.reportEdited`) when they
/// differ and it is about to write over it. Either way the user resolves the
/// conflict, before the project is written; the second one needs no baseline
/// of the file, which other processors that write it move.
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
  bool _edited = false;

  /// Edits the settings of the configurations of the project of [owned], which
  /// remembers what the lock recorded for its processor in the same file.
  OwnedBuildSettings(this._owned)
    : _previous = _owned.ctx.previousKeysOf(_owned.artifact.path);

  /// The hash the lock keeps of the [value] of a setting.
  static String hashOf(Object? value) =>
      digestOf(utf8.encode(jsonEncode(value)));

  /// The name the lock gives to the [setting] of the configuration with this
  /// [uuid], in a [scope].
  static String keyOf(String scope, String uuid, String setting) =>
      '$scope/$uuid/$setting';

  /// Sets the settings of [wanted] in [config], one by one, and owns them.
  ///
  /// The other settings of [config] are not touched. The values are copied: a
  /// list is never shared between two configurations.
  void apply(
    XCBuildConfiguration config, {
    required String scope,
    required Map<String, dynamic> wanted,
  }) {
    final before = _persisted(config);
    final settings = Map<String, dynamic>.of(config.buildSettings);

    for (final MapEntry(key: setting, value: value) in wanted.entries) {
      settings[setting] = _copy(value);
    }

    config.buildSettings = settings;

    final after = _persisted(config);

    for (final setting in wanted.keys) {
      final key = keyOf(scope, config.uuid, setting);
      final recorded = _previous[key];
      final found = before.containsKey(setting)
          ? hashOf(before[setting])
          : null;

      // What was there is not what flavorizr wrote, and is not what it writes
      // now either: somebody changed it, and it is about to be written over.
      if (recorded != null &&
          found != recorded &&
          found != hashOf(after[setting])) {
        _edited = true;
      }

      _written[key] = hashOf(after[setting]);
    }
  }

  /// Whether [config] holds settings that flavorizr did not write, once the
  /// ones it owns are gone: what a configuration that is not wanted anymore
  /// must not take with it when it is removed.
  ///
  /// A configuration of the target holds whatever it has left (flavorizr only
  /// makes it with `PRODUCT_NAME`). One of the project starts as a copy of the
  /// `Debug`, `Profile` or `Release` one, so it holds what differs from it.
  bool holdsOthers(XCBuildConfiguration config) {
    final project = _owned.project;
    final settings = _persisted(config);

    if (!project.buildConfigurationList.buildConfigurations.contains(config)) {
      return settings.isNotEmpty;
    }

    final base =
        project.buildConfigurationList[(config.name ?? '').split('-').first];

    if (base == null) return settings.isNotEmpty;

    final copied = _persisted(base);

    return settings.entries.any(
      (entry) =>
          !copied.containsKey(entry.key) ||
          jsonEncode(copied[entry.key]) != jsonEncode(entry.value),
    );
  }

  /// Ends the run on the settings: removes the ones the lock recorded that
  /// [apply] was not asked to set and still hold what flavorizr wrote, tells
  /// the context what it owns now, and whether the project was edited by hand.
  /// Returns the keys it removed, sorted.
  ///
  /// Call it once, after the last [apply]. A setting of a configuration that
  /// is no longer in the project is just forgotten, and so is a key the lock
  /// holds that is not the name of a setting of a configuration.
  List<String> settle() {
    final removed = <String>[];

    for (final MapEntry(key: key, value: hash) in _previous.entries.sorted(
      (a, b) => a.key.compareTo(b.key),
    )) {
      if (_written.containsKey(key)) continue;

      final parts = _parse(key);

      if (parts == null) continue;

      final (_, uuid, setting) = parts;
      final config = _owned.project.objectsByUuid[uuid];

      if (config is! XCBuildConfiguration ||
          !config.buildSettings.containsKey(setting) ||
          !_matches(config, setting, hash)) {
        continue;
      }

      config.buildSettings = Map.of(config.buildSettings)..remove(setting);
      removed.add(key);
    }

    _owned.ctx.ownKeys(_owned.artifact.path, _written);

    if (_edited) _owned.ctx.reportEdited(_owned.artifact.path);

    return removed;
  }

  /// Whether the [setting] of [config] holds the value that [hash] is of.
  static bool _matches(
    XCBuildConfiguration config,
    String setting,
    String hash,
  ) {
    final settings = _persisted(config);

    return settings.containsKey(setting) && hashOf(settings[setting]) == hash;
  }

  /// The settings of [config] as the project stores them. `dart_xcodeproj`
  /// normalizes them when it writes (a flag string of a setting that is a list
  /// becomes one, a list of one that is not becomes a string), so it is asked
  /// to.
  static Map<String, dynamic> _persisted(XCBuildConfiguration config) {
    final into = <String, dynamic>{};

    config.serializeAttribute('buildSettings', into);

    return into['buildSettings'] as Map<String, dynamic>;
  }

  /// `scope/uuid/setting`: the setting is everything after the second `/`.
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
