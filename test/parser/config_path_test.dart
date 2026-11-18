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

import 'package:flutter_flavorizr/src/parser/config_path.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

const _yaml = '''
flavors:
  apple:
    ios:
      includes:
        - path: a
        - path: b
          optional: true
''';

void main() {
  final root = loadYamlNode(_yaml) as YamlMap;
  final flavors = root.nodes['flavors'] as YamlMap;
  final ios = (flavors.nodes['apple'] as YamlMap).nodes['ios'] as YamlMap;
  final includes = ios.nodes['includes'] as YamlList;
  final second = includes.nodes[1] as YamlMap;

  group('configPathOf', () {
    test('is the keys down to a node, joined with dots', () {
      expect(configPathOf(root, flavors), 'flavors');
      expect(configPathOf(root, ios), 'flavors.apple.ios');
    });

    test('puts the position in a list in brackets', () {
      expect(configPathOf(root, includes), 'flavors.apple.ios.includes');
      expect(configPathOf(root, second), 'flavors.apple.ios.includes[1]');
      expect(
        configPathOf(root, second.nodes['optional']!),
        'flavors.apple.ios.includes[1].optional',
      );
    });

    test('tells a key from the map it starts', () {
      final key = second.nodes.keys.first as YamlNode;

      expect(configPathOf(root, key), 'flavors.apple.ios.includes[1].path');
      expect(configPathOf(root, second), 'flavors.apple.ios.includes[1]');
    });

    test('quotes a key with punctuation, so that it reads as written', () {
      final odd = loadYamlNode('"apple.[0]":\n  ok: 1\n') as YamlMap;
      final inner = (odd.nodes['apple.[0]'] as YamlMap).nodes['ok']!;

      expect(configPathOf(odd, inner), '"apple.[0]".ok');
    });

    test('is null for a node of another document', () {
      expect(configPathOf(root, loadYamlNode('other: 1')), isNull);
    });
  });

  group('configContainerPathOf', () {
    test('is the map itself for a map, and the map of a key', () {
      expect(
        configContainerPathOf(root, second),
        'flavors.apple.ios.includes[1]',
      );
      expect(
        configContainerPathOf(root, second.nodes.keys.first as YamlNode),
        'flavors.apple.ios.includes[1]',
      );
      expect(configContainerPathOf(root, loadYamlNode('x: 1')), isNull);
    });
  });
}
