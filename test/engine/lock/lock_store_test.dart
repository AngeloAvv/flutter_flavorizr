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
import 'dart:io';

import 'package:flutter_flavorizr/src/engine/lock/flavorizr_lock.dart';
import 'package:flutter_flavorizr/src/engine/lock/lock_codec.dart';
import 'package:flutter_flavorizr/src/engine/lock/lock_store.dart';
import 'package:flutter_flavorizr/src/engine/ownership.dart';
import 'package:flutter_flavorizr/src/exception/malformed_lock_file_exception.dart';
import 'package:flutter_flavorizr/src/exception/unsupported_lock_version_exception.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory project;
  late LockStore store;

  FlavorizrLock sample({String version = '3.0.0'}) => FlavorizrLock(
    flavorizrVersion: version,
    flavors: {'prod': 'sha256:bbb', 'dev': 'sha256:aaa'},
    processors: {
      'flutter:flavors': ProcessorLock(
        files: {
          'lib/flavors.dart': LockedFile(
            ownership: Ownership.managed,
            hash: 'sha256:111',
          ),
        },
      ),
    },
  );

  setUp(() {
    project = Directory.systemTemp.createTempSync('flavorizr_lock_store_');
    store = LockStore(project, runningVersion: '3.0.0');
  });

  tearDown(() => project.deleteSync(recursive: true));

  group('LockStore', () {
    test('has no lock in a project that never ran', () async {
      expect(await store.read(), isNull);
    });

    test('writes flavorizr.lock in the root of the project', () async {
      await store.write(sample());

      expect(File(p.join(project.path, 'flavorizr.lock')).existsSync(), isTrue);
      expect(LockStore.fileName, 'flavorizr.lock');
    });

    test('reads back what it wrote', () async {
      await store.write(sample());

      expect(await store.read(), sample());
    });

    test('two writes of the same content are byte identical', () async {
      final file = File(p.join(project.path, 'flavorizr.lock'));

      await store.write(sample());
      final first = file.readAsBytesSync();
      await store.write(sample());
      final second = file.readAsBytesSync();

      expect(second, first);
    });

    test('replaces a previous lock and leaves nothing else behind', () async {
      await store.write(sample());
      await store.write(FlavorizrLock(flavorizrVersion: '3.0.0'));

      expect(await store.read(), FlavorizrLock(flavorizrVersion: '3.0.0'));
      expect(project.listSync().map((e) => p.basename(e.path)), [
        'flavorizr.lock',
      ]);
    });

    test('writes UTF-8 without a byte order mark', () async {
      await store.write(
        FlavorizrLock(flavorizrVersion: '3.0.0', flavors: {'caffè': 'h'}),
      );

      final bytes = File(
        p.join(project.path, 'flavorizr.lock'),
      ).readAsBytesSync();

      expect(bytes.take(3), isNot([0xEF, 0xBB, 0xBF]));
      expect(utf8.decode(bytes), contains('caffè'));
    });

    test('refuses to read a lock written by a newer flavorizr', () async {
      File(p.join(project.path, 'flavorizr.lock')).writeAsStringSync(
        'flavorizrVersion: 3.1.0\n'
        'flavors: {}\n'
        'processors: {}\n'
        'schemaVersion: 1\n',
      );

      expect(store.read(), throwsA(isA<UnsupportedLockVersionException>()));
    });

    test('reads a lock saved with a byte order mark', () async {
      final text = LockCodec.encode(sample());
      File(
        p.join(project.path, 'flavorizr.lock'),
      ).writeAsBytesSync([0xEF, 0xBB, 0xBF, ...utf8.encode(text)]);

      expect(await store.read(), sample());
    });

    test('reports a lock that is not UTF-8 as malformed', () async {
      File(
        p.join(project.path, 'flavorizr.lock'),
      ).writeAsBytesSync([0xFF, 0xFE, 0x41]);

      expect(store.read(), throwsA(isA<MalformedLockFileException>()));
    });

    test('leaves no temporary file when the write fails', () async {
      // A directory in the place of the lock makes the final rename fail.
      Directory(p.join(project.path, 'flavorizr.lock')).createSync();

      await expectLater(store.write(sample()), throwsA(isA<IOException>()));

      expect(project.listSync().map((e) => p.basename(e.path)), [
        'flavorizr.lock',
      ]);
    });
  });
}
