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

import 'package:flutter_flavorizr/src/engine/lock/lock_store.dart';
import 'package:flutter_flavorizr/src/engine/ownership.dart';
import 'package:flutter_flavorizr/src/entrypoint/exit_codes.dart';
import 'package:flutter_flavorizr/src/entrypoint/processor_registry.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

import '../../../entrypoint/cli_fixture.dart';
import 'flutter_scheme.dart';

const _schemes = 'macos/Runner.xcodeproj/xcshareddata/xcschemes';
const _runner = '$_schemes/Runner.xcscheme';
const _example = 'test_resources/example_2x/macos/Runner.xcodeproj';

/// The processors of a run of the macOS schemes.
const _targets = ['flutter:flavors', 'macos:schema'];

/// The target `flutter create` makes, as the example project has it.
const _runnerUuid = '33CC10EC2044A3C60003C045';

const _prepare =
    '"\$FLUTTER_ROOT"/packages/flutter_tools/bin/macos_assemble.sh prepare\n';

const _config = '''
flavors:
  citrus:
    app:
      name: "Citrus App"
    macos:
      bundleId: "com.example.citrus"
  dates:
    app:
      name: "Dates App"
    macos:
      bundleId: "com.example.dates"
''';

const _spmOff =
    'name: app\nflutter:\n  config:\n    enable-swift-package-manager: false\n';

/// What the attribute [name] of the element [tag] of [scheme] is.
String? _attribute(String scheme, String tag, String name) =>
    XmlDocument.parse(scheme).rootElement.getElement(tag)?.getAttribute(name);

/// The build configurations of the five actions of [scheme], by action.
Map<String, String?> _configurations(String scheme) => {
  for (final action in [
    'LaunchAction',
    'TestAction',
    'ProfileAction',
    'AnalyzeAction',
    'ArchiveAction',
  ])
    action: _attribute(scheme, action, 'buildConfiguration'),
};

/// The scripts of the pre-actions of [scheme].
List<String> _preActionScripts(String scheme) => [
  for (final content in XmlDocument.parse(
    scheme,
  ).rootElement.findAllElements('ActionContent'))
    if (content.parentElement?.parentElement?.name.local == 'PreActions')
      content.getAttribute('scriptText') ?? '',
];

void main() {
  late CliFixture project;

  Future<int> apply() => project.run(['apply', '--yes', ..._targets]);

  String scheme(String flavor) => project.read('$_schemes/$flavor.xcscheme');

  setUp(() {
    project = CliFixture(android: false);
    project.write('flavorizr.yaml', _config);
    project.write(
      'macos/Runner.xcodeproj/project.pbxproj',
      File('$_example/project.pbxproj').readAsStringSync(),
    );
    project.write(
      _runner,
      File(
        '$_example/xcshareddata/xcschemes/Runner.xcscheme',
      ).readAsStringSync(),
    );
  });
  tearDown(() => project.dispose());

  test('macos:schema runs on the engine', () {
    final registry = ProcessorRegistry.standard();

    expect(registry.engineProcessors, contains('macos:schema'));
  });

  group('a new scheme', () {
    test('is made for every flavor, with its build configurations', () async {
      final code = await apply();

      expect(code, ExitCodes.ok, reason: project.logger.output);
      for (final flavor in ['citrus', 'dates']) {
        expect(_configurations(scheme(flavor)), {
          'LaunchAction': 'Debug-$flavor',
          'TestAction': 'Debug-$flavor',
          'ProfileAction': 'Profile-$flavor',
          'AnalyzeAction': 'Debug-$flavor',
          'ArchiveAction': 'Release-$flavor',
        });
      }
    });

    test(
      'builds the app the flavor configurations build, and tests its target',
      () async {
        await apply();

        final text = scheme('citrus');

        expect(text, contains('BlueprintIdentifier = "$_runnerUuid"'));
        // What the flavor configurations build: they set PRODUCT_NAME to
        // `$(TARGET_NAME)`, so the app is named after the target, not after the
        // product reference of the project (`example.app`).
        expect(text, contains('BuildableName = "Runner.app"'));
        expect(text, isNot(contains('example.app')));
        expect(
          text,
          contains('ReferencedContainer = "container:Runner.xcodeproj"'),
        );
        expect(text, contains('<BuildActionEntry'));
        expect(text, contains('BuildableName = "RunnerTests.xctest"'));
      },
    );

    test('names the product macos:buildTargets gives the configurations of the '
        'flavor', () async {
      final code = await project.run([
        'apply',
        '--yes',
        'macos:buildTargets',
        ..._targets,
      ]);
      final pbxproj = project.read('macos/Runner.xcodeproj/project.pbxproj');

      expect(code, ExitCodes.ok, reason: project.logger.output);
      // `$(TARGET_NAME)` of the target `Runner`, and the scheme says the same.
      expect(
        RegExp(
          r'PRODUCT_NAME = "\$\(TARGET_NAME\)";\s*\};\s*name = "Debug-citrus";',
        ).hasMatch(pbxproj),
        isTrue,
      );
      expect(scheme('citrus'), contains('BuildableName = "Runner.app"'));
    });

    test(
      'has the macOS pre-action of Flutter, which leaves it alone',
      () async {
        await apply();

        expect(_preActionScripts(scheme('citrus')), [_prepare]);
        expect(
          withFlutterPreAction(scheme('citrus'), platform: 'macos'),
          scheme('citrus'),
        );
      },
    );

    test('has no pre-action when the project disables Swift Package '
        'Manager', () async {
      project.write('pubspec.yaml', _spmOff);

      await apply();

      expect(_preActionScripts(scheme('citrus')), isEmpty);
    });

    test('is recorded as patched, and the scheme of Flutter is not '
        'owned', () async {
      await apply();

      final lock = (await LockStore(
        project.root,
        runningVersion: '3.0.0',
      ).read())!;

      expect(
        {
          for (final MapEntry(key: path, value: file)
              in lock.processors['macos:schema']!.files.entries)
            path: file.ownership,
        },
        {
          '$_schemes/citrus.xcscheme': Ownership.patched,
          '$_schemes/dates.xcscheme': Ownership.patched,
        },
      );
      expect(project.read(_runner), isNot(contains('Debug-citrus')));
    });

    test(
      'writes nothing for a launch screen, which macOS does not have',
      () async {
        await apply();

        expect(
          project.snapshot().keys.where(
            (path) => path.contains('LaunchScreen'),
          ),
          isEmpty,
        );
      },
    );
  });

  group('a second run', () {
    test('changes nothing', () async {
      await apply();
      final before = project.snapshot();

      final code = await apply();

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.snapshot(), before);
    });

    test('changes nothing after Flutter injected its pre-action', () async {
      project.write('pubspec.yaml', _spmOff);
      await apply();
      for (final flavor in ['citrus', 'dates']) {
        project.write(
          '$_schemes/$flavor.xcscheme',
          withFlutterPreAction(scheme(flavor), platform: 'macos'),
        );
      }
      project.write('pubspec.yaml', 'name: app\n');
      final before = project.snapshot();

      final code = await apply();

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.snapshot(), before);
      expect(_preActionScripts(scheme('citrus')), hasLength(1));
    });

    test(
      'reports a build configuration the user changed as a conflict',
      () async {
        await apply();
        project.write(
          '$_schemes/citrus.xcscheme',
          scheme('citrus').replaceFirst(
            'buildConfiguration = "Release-citrus"',
            'buildConfiguration = "Release"',
          ),
        );

        final code = await apply();

        expect(code, ExitCodes.attention, reason: project.logger.output);
        expect(_configurations(scheme('citrus'))['ArchiveAction'], 'Release');
      },
    );
  });

  group('an existing scheme', () {
    test('gets only its build configurations changed', () async {
      final user = File(
        '$_example/xcshareddata/xcschemes/Runner.xcscheme',
      ).readAsStringSync();
      project.write('$_schemes/citrus.xcscheme', user);

      final code = await apply();

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(
        scheme('citrus'),
        user
            .replaceAll('"Debug"', '"Debug-citrus"')
            .replaceAll('"Release"', '"Release-citrus"')
            .replaceAll('"Profile"', '"Profile-citrus"'),
      );
    });
  });
}
