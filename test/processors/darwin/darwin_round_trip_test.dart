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

void main() {
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

          expect(
            File('$copyPath/project.pbxproj').readAsStringSync(),
            File('$projectPath/project.pbxproj').readAsStringSync(),
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

            expect(
              File(copyPath).readAsStringSync(),
              scheme.readAsStringSync(),
            );
          });
        },
      );
    }
  }
}
