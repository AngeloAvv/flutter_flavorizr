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

import 'package:dart_xcodeproj/dart_xcodeproj.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:io/io.dart';
import 'package:path/path.dart' as p;

import '../../test_utils.dart';

/// Compares the content as it is stored: `readAsStringSync` decodes UTF-8 and
/// drops a leading BOM, so it would not see one being added or removed.
void expectSameContent(File actual, File expected) =>
    expect(actual.readAsBytesSync(), orderedEquals(expected.readAsBytesSync()));

void main() {
  test('Test the comparison of the round trips sees a BOM that is added', () {
    TestUtils.withTempDir((dir) {
      final withBom = File('${dir.path}/with_bom')
        ..writeAsBytesSync([0xEF, 0xBB, 0xBF, 0x61, 0x0A]);
      final withoutBom = File('${dir.path}/without_bom')
        ..writeAsBytesSync([0x61, 0x0A]);

      expect(
        () => expectSameContent(withBom, withoutBom),
        throwsA(isA<TestFailure>()),
      );
    });
  });

  for (final platform in ['ios', 'macos']) {
    final projectPath = 'example/$platform/Runner.xcodeproj';

    test(
      'Test dart_xcodeproj saves the pbxproj of the $platform example byte for byte when nothing changes',
      () async {
        await TestUtils.withTempDir((dir) async {
          final copyPath = '${dir.path}/Runner.xcodeproj';
          copyPathSync(projectPath, copyPath);

          final project = await XcodeProject.open(copyPath);
          await project.save();

          expectSameContent(
            File('$copyPath/project.pbxproj'),
            File('$projectPath/project.pbxproj'),
          );
        });
      },
    );

    final schemes = Directory('$projectPath/xcshareddata/xcschemes')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.xcscheme'));

    for (final scheme in schemes) {
      test(
        'Test dart_xcodeproj saves the ${p.basename(scheme.path)} scheme of the $platform example byte for byte when nothing changes',
        () async {
          await TestUtils.withTempDir((dir) async {
            final copyPath = '${dir.path}/${p.basename(scheme.path)}';

            final opened = await XCScheme.open(scheme.path);
            await opened.saveAs(copyPath);

            expectSameContent(File(copyPath), scheme);
          });
        },
      );
    }
  }
}
