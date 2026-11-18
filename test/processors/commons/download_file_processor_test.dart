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

import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:flutter_flavorizr/src/processors/commons/download_file_processor.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_utils.dart';

FlavorizrConfig _configDownloadingFrom(String url) => FlavorizrConfig.parse('''
assetsUrl: $url
flavors:
  apple:
    app:
      name: Apple
    android:
      applicationId: com.example.apple
''');

void main() {
  test('DownloadFileProcessor.execute returns the future of the download', () {
    return TestUtils.withTempDir((dir) async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        request.response.add([1, 2, 3]);
        await request.response.close();
      });
      final path = '${dir.path}/assets.zip';
      final processor = DownloadFileProcessor(
        path,
        config: _configDownloadingFrom(
          'http://${server.address.host}:${server.port}/assets.zip',
        ),
        logger: TestUtils.quietLogger(),
      );

      // Compiles only when `execute` returns a future, which is what lets the
      // caller wait for the file to be written.
      final Future<void> download = processor.execute();
      await download;

      expect(File(path).readAsBytesSync(), [1, 2, 3]);
    });
  });

  test('DownloadFileProcessor.execute fails the future when it cannot connect',
      () {
    return TestUtils.withTempDir((dir) async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final url = 'http://${server.address.host}:${server.port}/assets.zip';
      await server.close(force: true);
      final processor = DownloadFileProcessor(
        '${dir.path}/assets.zip',
        config: _configDownloadingFrom(url),
        logger: TestUtils.quietLogger(),
      );

      await expectLater(processor.execute(), throwsA(isA<SocketException>()));
    });
  });
}
