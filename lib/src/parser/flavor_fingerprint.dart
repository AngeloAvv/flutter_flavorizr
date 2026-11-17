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

import 'package:crypto/crypto.dart';

/// The fingerprint of the resolved configuration of each flavor of a
/// configuration, by flavor name.
///
/// [json] is the decoded configuration. A flavor is resolved against the
/// shared `app` section, so the fingerprint covers both: changing the flavor
/// or the section changes it, while anything else, such as another flavor, a
/// recipe or the order of the keys, does not. It is what `flavorizr.lock`
/// records to tell which flavors changed since the last run.
Map<String, String> fingerprintFlavors(Map<dynamic, dynamic> json) {
  final flavors = json['flavors'];

  if (flavors is! Map) return const {};

  final shared = _canonical(json['app']);

  return {
    for (final MapEntry(:key, :value) in flavors.entries)
      '$key': _digest(jsonEncode({'app': shared, 'flavor': _canonical(value)})),
  };
}

String _digest(String text) => 'sha256:${sha256.convert(utf8.encode(text))}';

/// [value] as plain JSON data whose maps are sorted by key.
Object? _canonical(Object? value) => switch (value) {
  Map() => Map.fromEntries(
    [
      for (final MapEntry(:key, :value) in value.entries)
        MapEntry('$key', _canonical(value)),
    ]..sort((a, b) => a.key.compareTo(b.key)),
  ),
  List() => [for (final element in value) _canonical(element)],
  num() || bool() || String() || null => value,
  _ => '$value',
};
