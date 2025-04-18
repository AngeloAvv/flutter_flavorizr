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

import 'package:flutter_flavorizr/src/processors/commons/abstract_file_processor.dart';

class DownloadFileProcessor extends AbstractFileProcessor {
  final String _url;

  DownloadFileProcessor(
    super.path, {
    required super.config,
    required super.logger,
  })  : _url = config.assetsUrl;

  @override
  void execute() async {
    logger.detail(
      '[$DownloadFileProcessor] Initializing HttpClient',
    );
    HttpClient client = HttpClient();

    logger.detail(
      '[$DownloadFileProcessor] Downloading file from $_url',
    );
    HttpClientRequest request = await client.getUrl(Uri.parse(_url));
    HttpClientResponse response = await request.close();

    logger.detail(
      '[$DownloadFileProcessor] Downloading file to $path',
    );

    await response.pipe(file.openWrite());

    logger.detail(
      '[$DownloadFileProcessor] File downloaded to $path',
      style: logger.theme.success,
    );
  }

  @override
  String toString() => 'DownloadFileProcessor: { url: $_url, path: $path }';
}
