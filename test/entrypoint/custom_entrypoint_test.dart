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

import 'package:flutter_flavorizr/src/entrypoint/custom_entrypoint.dart';
import 'package:test/test.dart';

void main() {
  late Directory project;
  late List<List<String>> started;
  late List<Map<String, String>> environments;

  Future<int> start(
    String executable,
    List<String> arguments, {
    required String workingDirectory,
    required Map<String, String> environment,
  }) async {
    started.add([executable, workingDirectory, ...arguments]);
    environments.add(environment);

    return 7;
  }

  setUp(() {
    project = Directory.systemTemp.createTempSync('flavorizr_entrypoint_');
    started = [];
    environments = [];
  });
  tearDown(() => project.deleteSync(recursive: true));

  void createEntrypoint() => File('${project.path}/tool/flavorizr.dart')
    ..parent.createSync(recursive: true)
    ..writeAsStringSync('void main() {}');

  Future<int?> delegate(
    List<String> args, {
    Map<String, String> environment = const {},
  }) => delegateToCustomEntrypoint(
    args,
    projectRoot: project,
    environment: environment,
    start: start,
    dart: 'dart',
  );

  test('runs tool/flavorizr.dart with the arguments, and returns its exit '
      'code', () async {
    createEntrypoint();

    expect(await delegate(['plan', '--json']), 7);
    expect(started, [
      ['dart', project.path, 'run', 'tool/flavorizr.dart', 'plan', '--json'],
    ]);
  });

  test('sets the guard on the entry point it runs', () async {
    createEntrypoint();

    await delegate([]);

    expect(environments.single, {delegationGuard: '1'});
  });

  test(
    'does not delegate when the project has no entry point of its own',
    () async {
      expect(await delegate(['apply']), isNull);
      expect(started, isEmpty);
    },
  );

  test('does not delegate again from the entry point it ran', () async {
    createEntrypoint();

    expect(
      await delegate(['apply'], environment: {delegationGuard: '1'}),
      isNull,
    );
    expect(started, isEmpty);
  });

  test('delegates once: what it starts does not delegate', () async {
    createEntrypoint();

    await delegate(['apply']);
    final child = {...environments.single};

    expect(await delegate(['apply'], environment: child), isNull);
    expect(started, hasLength(1));
  });
}
