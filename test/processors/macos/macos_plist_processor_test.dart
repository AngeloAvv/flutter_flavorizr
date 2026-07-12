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

import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:flutter_flavorizr/src/processors/macos/macos_plist_processor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:xml/xml.dart';

import '../../test_utils.dart';

void main() {
  late Flavorizr flavorizr;
  late Logger logger;

  setUp(() {
    logger = TestUtils.quietLogger();
    flavorizr = TestUtils.parseFlavorizr('test_resources/pubspec');
  });

  test('MacOSPListProcessor.execute replaces CFBundleName with the BUNDLE_NAME variable',
      () {
    String content =
        File('test_resources/macos/plist_processor_test/Info.plist')
            .readAsStringSync();

    MacOSPListProcessor processor = MacOSPListProcessor(
      input: content,
      config: flavorizr,
      logger: logger,
    );
    String actual = processor.execute();

    XmlDocument document = XmlDocument.parse(actual);
    XmlElement root =
        document.rootElement.children.whereType<XmlElement>().first;
    final keys =
        root.children.where((e) => e is XmlElement && e.name.local == 'key');
    final bundleNameKey =
        keys.firstWhere((e) => e.innerText == 'CFBundleName');
    final bundleNameValue = bundleNameKey.following
        .firstWhere((e) => e is XmlElement && e.name.local == 'string');

    expect(bundleNameValue.innerText, r'$(BUNDLE_NAME)');
  });

  test('Test malformed MacOSPListProcessor throws when CFBundleName key is missing',
      () {
    final malformed = '''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key>
	<string>\$(EXECUTABLE_NAME)</string>
</dict>
</plist>
''';

    MacOSPListProcessor processor = MacOSPListProcessor(
      input: malformed,
      config: flavorizr,
      logger: logger,
    );

    expect(() => processor.execute(), throwsException);
  });

}
