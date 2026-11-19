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

import 'package:flutter_flavorizr/src/engine/processors/flutter/flutter_sources.dart';
import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;

const _config = '''
flavors:
  apple:
    app:
      name: "Apple App"
  Banana:
    app:
      name: "Banana's \$App"
''';

const _check = '''
import 'package:app/flavors.dart';
import 'package:flutter/services.dart' as services;

void main() {
  for (final raw in <String?>[null, 'apple', 'Banana', 'banana', 'cherry']) {
    services.appFlavor = raw;

    try {
      print('\$raw => \${F.appFlavor} \${F.appFlavor.flavorName} \${F.name} '
          '\${F.title}');
    } on StateError catch (error) {
      print('\$raw => \${error.message}');
    }
  }
}
''';

/// Whether `dart` can be run, which is what a test of generated code needs.
bool get _hasDart {
  try {
    return Process.runSync('dart', ['--version']).exitCode == 0;
  } on ProcessException {
    return false;
  }
}

/// Analyzes and runs the code the processor generates, against a stand-in for
/// the one thing it takes from Flutter: `appFlavor`.
void main() {
  late Directory app;

  ProcessResult dart(List<String> arguments) =>
      Process.runSync('dart', arguments, workingDirectory: app.path);

  void write(String path, String content) => File(p.join(app.path, path))
    ..createSync(recursive: true)
    ..writeAsStringSync(content);

  setUpAll(() {
    final temp = Directory.systemTemp.createTempSync('flavorizr_generated_');
    addTearDown(() => temp.deleteSync(recursive: true));

    app = Directory(p.join(temp.path, 'app'))..createSync();
    write('stub/pubspec.yaml', 'name: flutter\nenvironment:\n  sdk: ^3.0.0\n');
    write('stub/lib/services.dart', 'String? appFlavor;\n');
    write(
      'pubspec.yaml',
      'name: app\nenvironment:\n  sdk: ^3.0.0\n'
          'dependencies:\n  flutter:\n    path: stub\n',
    );
    write(
      'lib/flavors.g.dart',
      flavorsGeneratedSource(FlavorizrConfig.parse(_config)),
    );
    write('lib/flavors.dart', flavorsScaffoldSource);
    write('bin/check.dart', _check);

    final pubGet = dart(['pub', 'get', '--offline']);

    expect(pubGet.exitCode, 0, reason: '${pubGet.stdout}${pubGet.stderr}');
  });

  group('the generated flavors', () {
    test('pass the analyzer, lints of the app included', () {
      final result = dart(['analyze', '--fatal-infos', 'lib']);

      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    });

    test('are found by the name `appFlavor` holds, or explain what is '
        'wrong', () {
      final result = dart(['run', 'bin/check.dart']);

      expect(result.exitCode, 0, reason: '${result.stderr}');
      expect((result.stdout as String).trim().split('\n'), [
        'null => The app was built without a flavor. Build or run it with '
            '--flavor <name>, where <name> is one of: apple, Banana.',
        "apple => Flavor.apple apple apple Apple App",
        "Banana => Flavor.banana Banana banana Banana's \$App",
        'banana => The app was built with the flavor "banana", which '
            'flavorizr.yaml does not define. Its flavors are: apple, Banana.',
        'cherry => The app was built with the flavor "cherry", which '
            'flavorizr.yaml does not define. Its flavors are: apple, Banana.',
      ]);
    });
  }, skip: _hasDart ? null : 'dart is not on the PATH');
}
