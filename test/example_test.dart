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

import 'package:flutter_flavorizr/src/entrypoint/exit_codes.dart';
import 'package:flutter_flavorizr/src/entrypoint/processor_registry.dart';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;

import '../example/tool/flavors_doc_processor.dart';
import 'entrypoint/cli_fixture.dart';

/// What of `example/` is not part of the project: it is made by the tools.
const _generated = {'.dart_tool', 'build', 'Pods', '.idea', '.gradle'};

void _copy(Directory from, Directory to) {
  for (final entity in from.listSync()) {
    final name = p.basename(entity.path);

    if (_generated.contains(name)) continue;

    switch (entity) {
      case Directory():
        _copy(entity, Directory(p.join(to.path, name))..createSync());
      case File():
        entity.copySync(p.join(to.path, name));
      case _:
    }
  }
}

/// `example/` is committed flavorized, with its lock: this is what the drift
/// job of the pipeline checks, with the custom processor it registers in
/// `tool/flavorizr.dart`.
void main() {
  late CliFixture project;

  setUp(() {
    project = CliFixture(android: false);

    for (final entity in project.root.listSync()) {
      entity.deleteSync(recursive: true);
    }

    _copy(Directory('example'), project.root);
    project.registry = ProcessorRegistry.standard().withProcessors(const [
      FlavorsDocProcessor(),
    ]);
  });
  tearDown(() => project.dispose());

  test('is in sync with its lock', () async {
    final code = await project.run(['status']);

    expect(code, ExitCodes.ok, reason: project.logger.output);
  });

  test(
    'has nothing left to do, but the local run configurations of the IDE',
    () async {
      final code = await project.run(['plan']);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      // The run configurations of the IDE are local: git ignores `.idea/`, so a
      // clone has none, and they are not what the lock vouches for.
      final changes = project.logger.lines.where(
        (line) => RegExp(r'\((managed|patched|scaffold)\)').hasMatch(line),
      );

      expect(changes, isEmpty);
      expect(project.logger.output, contains('0 conflicts'));
    },
  );

  test('lists the flavors in FLAVORS.md, which a custom processor owns', () {
    final doc = project.read('FLAVORS.md');

    expect(doc, contains('| `apple` | Apple App |'));
    expect(doc, contains('| `banana` | Banana App |'));
    expect(project.read('flavorizr.lock'), contains('acme:flavorsDoc'));
  });

  test('reports a change of a file the custom processor wrote', () async {
    project.write('FLAVORS.md', '# edited by hand');

    final code = await project.run(['status']);

    expect(code, ExitCodes.attention, reason: project.logger.output);
    expect(project.logger.output, contains('FLAVORS.md'));
  });
}
