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

import 'package:flutter_flavorizr/src/engine/artifact.dart';
import 'package:flutter_flavorizr/src/engine/flavorizr_context.dart';
import 'package:flutter_flavorizr/src/engine/flavorizr_processor.dart';
import 'package:flutter_flavorizr/src/engine/processors/flutter/flutter_processors.dart';
import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../../test_utils.dart';

const _config = '''
flavors:
  apple:
    app:
      name: "Apple App"
  Banana:
    app:
      name: "Banana's \$App"
''';

String _golden(String name) => File(
  'test/engine/processors/flutter/golden/$name.golden',
).readAsStringSync().replaceAll('\r\n', '\n');

void main() {
  late Directory root;
  late Directory projectRoot;

  FlavorizrContext contextFor(String yaml) => FlavorizrContext(
    config: Flavorizr.parse(yaml),
    root: root,
    projectRoot: projectRoot,
    logger: TestUtils.quietLogger(),
  );

  String read(String path) => File(p.join(root.path, path)).readAsStringSync();

  setUp(() {
    final temp = Directory.systemTemp.createTempSync('flavorizr_flutter_');
    addTearDown(() => temp.deleteSync(recursive: true));

    root = Directory(p.join(temp.path, 'shadow'))..createSync();
    projectRoot = Directory(p.join(temp.path, 'project'))..createSync();
  });

  group('FlutterFlavorsProcessor', () {
    test('is the `flutter:flavors` processor, with no edges', () {
      const processor = FlutterFlavorsProcessor();

      expect(processor.id, 'flutter:flavors');
      expect(processor.dependsOn, isEmpty);
      expect(processor.after, isEmpty);
      expect(processor.requires, isEmpty);
    });

    test(
      'writes flavors.g.dart as managed and flavors.dart as scaffold',
      () async {
        final ctx = contextFor(_config);

        await const FlutterFlavorsProcessor().apply(ctx);

        expect(read('lib/flavors.g.dart'), _golden('flavors.g.dart'));
        expect(read('lib/flavors.dart'), _golden('flavors.dart'));
        expect(ctx.tracked, [
          const Artifact.managed('lib/flavors.g.dart'),
          const Artifact.scaffold('lib/flavors.dart'),
        ]);
      },
    );

    test('regenerates flavors.g.dart from scratch: a dropped flavor is gone, '
        'and a second run changes nothing', () async {
      await const FlutterFlavorsProcessor().apply(contextFor(_config));

      const apple = '''
flavors:
  apple:
    app:
      name: "Apple App"
''';

      await const FlutterFlavorsProcessor().apply(contextFor(apple));
      final once = read('lib/flavors.g.dart');

      expect(once, isNot(contains('Banana')));
      expect(once, contains("apple('apple');"));

      await const FlutterFlavorsProcessor().apply(contextFor(apple));

      expect(read('lib/flavors.g.dart'), once);
    });

    test('keeps the name of a flavor as it was written, and lower-cases the '
        'member of the enum', () async {
      await const FlutterFlavorsProcessor().apply(contextFor(_config));

      final source = read('lib/flavors.g.dart');

      expect(source, contains("banana('Banana')"));
      expect(source, contains('case Flavor.banana:'));
    });

    test('escapes what would break or interpolate a string', () async {
      await const FlutterFlavorsProcessor().apply(contextFor(_config));

      expect(
        read('lib/flavors.g.dart'),
        contains(r"return 'Banana\'s \$App';"),
      );
    });
  });

  group('the scaffold processors', () {
    final cases = <(FlavorizrProcessor, String, String, Set<String>, String)>[
      (
        const FlutterPagesProcessor(),
        'flutter:pages',
        'lib/pages/my_home_page.dart',
        {'flutter:flavors'},
        'my_home_page.dart',
      ),
      (
        const FlutterAppProcessor(),
        'flutter:app',
        'lib/app.dart',
        {'flutter:flavors', 'flutter:pages'},
        'app.dart',
      ),
      (
        const FlutterMainProcessor(),
        'flutter:main',
        'lib/main.dart',
        {'flutter:app'},
        'main.dart',
      ),
    ];

    for (final (processor, id, path, dependsOn, golden) in cases) {
      test('$id scaffolds $path and needs $dependsOn', () async {
        final ctx = contextFor(_config);

        expect(processor.id, id);
        expect(processor.dependsOn, dependsOn);
        expect(processor.after, isEmpty);
        expect(processor.requires, isEmpty);

        await processor.apply(ctx);

        expect(read(path), _golden(golden));
        expect(ctx.tracked, [Artifact.scaffold(path)]);
      });
    }

    test('main.dart initializes nothing: F.appFlavor reads the flavor', () {
      final source = _golden('main.dart');

      expect(source, isNot(contains('F.appFlavor')));
      expect(source, isNot(contains('services.dart')));
      expect(source, contains('runApp(const App());'));
    });
  });
}
