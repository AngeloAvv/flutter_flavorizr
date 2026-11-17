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

import 'package:flutter_flavorizr/src/entrypoint/cli_context.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory scratch;

  setUp(
    () => scratch = Directory.systemTemp.createTempSync('flavorizr_probe_'),
  );
  tearDown(() => scratch.deleteSync(recursive: true));

  /// An executable that runs [body], in a POSIX shell.
  String script(String body) {
    final file = File(p.join(scratch.path, 'flutter'))
      ..writeAsStringSync('#!/bin/sh\n$body\n');

    Process.runSync('chmod', ['+x', file.path]);

    return file.path;
  }

  bool alive(int pid) => Process.runSync('kill', ['-0', '$pid']).exitCode == 0;

  group('probeFlutterVersion', () {
    test('reads the version, whatever is printed before the JSON', () async {
      final flutter = script(
        'echo "Updating the tool..."\n'
        'echo \'{"frameworkVersion": "3.47.9"}\'',
      );

      expect(await probeFlutterVersion(executable: flutter), '3.47.9');
    });

    test('is null when flutter fails', () async {
      expect(await probeFlutterVersion(executable: script('exit 3')), isNull);
    });

    test('is null when there is no flutter', () async {
      expect(
        await probeFlutterVersion(executable: p.join(scratch.path, 'missing')),
        isNull,
      );
    });

    test('does not leave flutter running after the timeout', () async {
      final pidFile = File(p.join(scratch.path, 'pid'));
      final flutter = script('echo \$\$ > "${pidFile.path}"\nexec sleep 60');

      final version = await probeFlutterVersion(
        executable: flutter,
        timeout: const Duration(milliseconds: 500),
      );
      final pid = int.parse(pidFile.readAsStringSync().trim());

      expect(version, isNull);
      // The kill is delivered before the probe returns; give the OS a moment
      // to reap the process.
      for (var i = 0; i < 20 && alive(pid); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      expect(alive(pid), isFalse);
    });
  }, skip: Platform.isWindows ? 'needs a POSIX shell' : false);
}
