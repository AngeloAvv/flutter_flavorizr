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

import 'package:yaml/yaml.dart';

/// The path of [target] in the document [root], as a user reads it in the file:
/// `flavors.apple.ios.bundleId`, with the position in a list in brackets.
///
/// [target] has to be a node of [root] itself, not of another load of the same
/// text. `null` when it is not found.
String? configPathOf(YamlNode root, YamlNode target) =>
    _join(configPathSegmentsOf(root, target));

/// The segments of [configPathOf]: the keys, and the positions in a list as
/// integers.
List<Object>? configPathSegmentsOf(YamlNode root, YamlNode target) =>
    _find(root, target, const []);

/// The path made of [segments], as [configPathOf] spells it.
String joinConfigPath(List<Object> segments) => _join(segments)!;

/// Joins [segments]: a key after a dot, with quotes when it has a character
/// that would make the path ambiguous, and a position in brackets.
String? _join(List<Object>? segments) {
  if (segments == null) return null;

  final path = StringBuffer();

  for (final segment in segments) {
    switch (segment) {
      case int():
        path.write('[$segment]');
      case String():
        if (path.isNotEmpty) path.write('.');

        path.write(
          RegExp(r'^[^.\[\]"\\\s]+$').hasMatch(segment)
              ? segment
              : '"${_escape(segment)}"',
        );
    }
  }

  return path.toString();
}

/// The path of the map that holds [target], a key or a map, which is how the
/// errors of a map are told: `flavors.apple` for `flavors.apple.bundle_id`.
///
/// A [key] is the key of a map, even when it is itself a map: the path is then
/// the one of the map it is a key of.
String? configContainerPathOf(
  YamlNode root,
  YamlNode target, {
  bool key = false,
}) {
  final segments = configPathSegmentsOf(root, target);

  if (segments == null) return null;

  return _join(
    target is YamlMap && !key
        ? segments
        : segments.take(segments.length - 1).toList(),
  );
}

String _escape(String key) =>
    key.replaceAll(r'\', r'\\').replaceAll('"', r'\"');

List<Object>? _find(
  YamlNode node,
  YamlNode target,
  List<Object> path, [
  Set<YamlNode>? seen,
]) {
  if (identical(node, target)) return path;

  // An alias is the very same node: it is looked into once, at the place it
  // is met first, or a document of aliases of aliases would take forever.
  final visited = seen ?? Set<YamlNode>.identity();

  if (!visited.add(node)) return null;

  if (node is YamlMap) {
    for (final entry in node.nodes.entries) {
      final key = entry.key as YamlNode;
      final name = key is YamlScalar ? '${key.value}' : key.toString();

      if (identical(key, target)) return [...path, name];

      final found = _find(entry.value, target, [...path, name], visited);

      if (found != null) return found;
    }
  } else if (node is YamlList) {
    for (final (index, item) in node.nodes.indexed) {
      final found = _find(item, target, [...path, index], visited);

      if (found != null) return found;
    }
  }

  return null;
}
