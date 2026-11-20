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

import 'package:flutter_flavorizr/src/engine/flavorizr_context.dart';
import 'package:flutter_flavorizr/src/engine/processors/darwin/build_targets_processors.dart';
import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:flutter_flavorizr/src/engine/processors/darwin/darwin_icon_name.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../../../test_utils.dart';

String _yaml(String flavor) =>
    '''
flavors:
  dev:
    app:
      name: "App"
$flavor    ios:
      bundleId: "com.example.dev"
    macos:
      bundleId: "com.example.dev"
''';

void main() {
  late Directory temp;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('flavorizr_badge_targets_');
    addTearDown(() => temp.deleteSync(recursive: true));
  });

  Map<String, dynamic> iosSettings(String yaml) {
    final config = FlavorizrConfig.parse(yaml);

    return const IosBuildTargetsProcessor().buildSettings(
      FlavorizrContext(
        config: config,
        root: Directory(p.join(temp.path, 'shadow'))..createSync(),
        projectRoot: Directory(p.join(temp.path, 'project'))..createSync(),
        logger: TestUtils.quietLogger(),
      ),
      'dev',
      config.flavors['dev']!,
    );
  }

  Map<String, dynamic> macosSettings(String yaml) {
    final config = FlavorizrConfig.parse(yaml);

    return const MacosBuildTargetsProcessor().buildSettings(
      FlavorizrContext(
        config: config,
        root: Directory(p.join(temp.path, 'shadow'))..createSync(),
        projectRoot: Directory(p.join(temp.path, 'project'))..createSync(),
        logger: TestUtils.quietLogger(),
      ),
      'dev',
      config.flavors['dev']!,
    );
  }

  group('the app icon of a flavor', () {
    test('is the AppIcon of the project when it has no icon and no badge', () {
      expect(iosSettings(_yaml(''))[DarwinIconName.setting], 'AppIcon');
      expect(macosSettings(_yaml(''))[DarwinIconName.setting], 'AppIcon');
    });

    test('is the set of the flavor when it has a badge, as it has icons made '
        'for it', () {
      final yaml = _yaml('    badge: true\n');

      expect(
        iosSettings(yaml)[DarwinIconName.setting],
        DarwinIconName.flavorSet,
      );
      expect(
        macosSettings(yaml)[DarwinIconName.setting],
        DarwinIconName.flavorSet,
      );
    });
  });
}
