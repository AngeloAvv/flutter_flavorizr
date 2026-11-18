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

import 'dart:io';

import 'package:flutter_flavorizr/src/engine/artifact.dart';
import 'package:flutter_flavorizr/src/engine/flavorizr_context.dart';
import 'package:flutter_flavorizr/src/engine/processors/ide/ide_config_processor.dart';
import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../../test_utils.dart';

String _config(Iterable<String> flavors, {String ide = 'idea'}) =>
    'flavors:\n${[for (final flavor in flavors) '  "$flavor":\n    app:\n      name: $flavor\n'].join()}ide:\n  - $ide\n';

void main() {
  late Directory root;

  FlavorizrContext contextFor(String yaml, {Set<String> previous = const {}}) =>
      FlavorizrContext(
        config: Flavorizr.parse(yaml),
        root: root,
        projectRoot: root,
        logger: TestUtils.quietLogger(),
        previousFlavors: previous,
      );

  setUp(() {
    root = Directory.systemTemp.createTempSync('flavorizr_ide_');
    addTearDown(() => root.deleteSync(recursive: true));
  });

  test('is the `ide:config` processor, with no edges', () {
    const processor = IdeConfigProcessor();

    expect(processor.id, 'ide:config');
    expect(processor.dependsOn, isEmpty);
    expect(processor.after, isEmpty);
    expect(processor.requires, isEmpty);
  });

  test('tracks what it writes as local', () async {
    final ctx = contextFor(_config(['apple']));

    await const IdeConfigProcessor().apply(ctx);

    expect(ctx.tracked, [
      const Artifact.local('.idea/runConfigurations/apple.xml'),
    ]);
  });

  test('writes the launch.json of VS Code as local too', () async {
    final ctx = contextFor(_config(['apple'], ide: 'vscode'));

    await const IdeConfigProcessor().apply(ctx);

    expect(ctx.tracked, [const Artifact.local('.vscode/launch.json')]);
    expect(File(p.join(root.path, '.vscode/launch.json')).existsSync(), isTrue);
  });

  test('refuses a flavor that cannot be the name of a file', () async {
    final ctx = contextFor(_config(['a/b']));

    await expectLater(
      const IdeConfigProcessor().apply(ctx),
      throwsArgumentError,
    );
  });

  test(
    'does not look for the file of a dropped flavor outside the folder',
    () async {
      final outside = File(p.join(root.path, 'victim.xml'))
        ..writeAsStringSync('x');
      final ctx = contextFor(
        _config(['apple']),
        previous: {'../../victim', '../victim', '..', ''},
      );

      await const IdeConfigProcessor().apply(ctx);

      expect(outside.existsSync(), isTrue);
      expect(ctx.tracked, hasLength(1));
    },
  );

  test('has nothing to do without `ide`', () async {
    final ctx = contextFor('flavors:\n  apple:\n    app:\n      name: apple\n');

    await const IdeConfigProcessor().apply(ctx);

    expect(ctx.tracked, isEmpty);
  });
}
