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

import 'package:flutter_flavorizr/src/entrypoint/processor_registry.dart';
import 'package:flutter_flavorizr/src/entrypoint/run_plan.dart';
import 'package:flutter_flavorizr/src/exception/unknown_target_exception.dart';
import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:test/test.dart';

import 'cli_fixture.dart';

void main() {
  final registry = ProcessorRegistry.standard();

  RunPlan resolve(String yaml, [List<String> targets = const []]) =>
      resolveRunPlan(
        registry: registry,
        config: FlavorizrConfig.parse(yaml),
        targets: targets,
      );

  List<String> engine(RunPlan plan) => [
    for (final step in plan.engine.steps)
      '${step.processor.id}${step.auto ? ' (auto)' : ''}',
  ];

  final android = CliFixture.config(['apple']);

  test('resolves a recipe into processors, in dependency order', () {
    final plan = resolve(android, ['android']);

    expect(engine(plan), [
      'android:androidManifest',
      'android:dummyAssets',
      'android:flavorizrGradle',
      'android:buildGradle',
      'android:icons',
    ]);
  });

  test('pulls in what a processor depends on, and says so', () {
    final plan = resolve(android, ['android:buildGradle']);

    expect(engine(plan), [
      'android:flavorizrGradle (auto)',
      'android:buildGradle',
    ]);
  });

  test('the default is the `all` recipe', () {
    final plan = resolve(android);

    expect(engine(plan), hasLength(9));
    expect(
      engine(plan),
      containsAll(['ide:config', 'android:firebase', 'huawei:agconnect']),
    );
  });

  test('leaves out the platforms without flavors, with a message', () {
    final plan = resolve(android, ['android', 'ios']);

    expect(plan.messages, [
      'Skipping "ios": no flavors are configured for ios.',
    ]);
  });

  test('the default recipe of the configuration is used without targets', () {
    final plan = resolve(
      '$android'
      'recipes:\n  default:\n    - android:flavorizrGradle\n'
      '    - android:dummyAssets\n',
    );

    expect(engine(plan), ['android:dummyAssets', 'android:flavorizrGradle']);
  });

  test('a default recipe that is empty runs nothing', () {
    final plan = resolve('${android}recipes:\n  default: []\n');

    expect(plan.isEmpty, isTrue);
    expect(plan.engine.steps, isEmpty);
  });

  test('a target wins over an empty default recipe', () {
    final plan = resolve('${android}recipes:\n  default: []\n', [
      'android:icons',
    ]);

    expect(engine(plan), ['android:icons']);
  });

  test('a target wins over the default recipe', () {
    final plan = resolve(
      '${android}recipes:\n  default:\n    - android:dummyAssets\n',
      ['android:icons'],
    );

    expect(engine(plan), ['android:icons']);
  });

  test('the recipes of the configuration are targets', () {
    final yaml =
        '${android}recipes:\n  ci: [android:icons, android:dummyAssets]\n';

    final plan = resolve(yaml, ['ci']);

    expect(engine(plan), ['android:dummyAssets', 'android:icons']);
  });

  test('the default recipe of the configuration runs without targets', () {
    final yaml = '${android}recipes:\n  ci: [android:icons]\n  default: ci\n';

    final plan = resolve(yaml);

    expect(engine(plan), ['android:icons']);
  });

  test('an unknown target says what it looks like', () {
    expect(
      () => resolve(android, ['andriod']),
      throwsA(
        isA<UnknownTargetException>().having(
          (e) => e.suggestion,
          'suggestion',
          'android',
        ),
      ),
    );
  });

  test('the shadow workspace holds what the processors work on', () {
    final plan = resolve(android, ['android:buildGradle']);

    expect(plan.paths, {
      'android/app/flavorizr.gradle',
      'android/app/flavorizr.gradle.kts',
      'android/app/build.gradle',
      'android/app/build.gradle.kts',
    });
  });

  group('android:dummyAssets', () {
    test('runs on the engine, before the icons', () {
      final plan = resolve(android, ['android:icons', 'android:dummyAssets']);

      expect(engine(plan), ['android:dummyAssets', 'android:icons']);
      expect(plan.paths, {'android/app/src'});
    });
  });

  group('the linux processors', () {
    final linux = '''
flavors:
  apple:
    app:
      name: "Apple"
    linux:
      applicationId: "com.example.apple"
''';

    test('run on the engine, in the order of the recipe, ', () {
      final plan = resolve(linux, ['linux']);

      expect(engine(plan), [
        'linux:cmake',
        'linux:runnerCmake',
        'linux:myApplication',
      ]);
      expect(plan.paths, {
        'linux/CMakeLists.txt',
        'linux/runner/CMakeLists.txt',
        'linux/runner/my_application.cc',
      });
    });

    test(
      'are left out of the default run of a project with no linux flavors',
      () {
        final plan = resolve(android);

        expect(engine(plan), isNot(contains('linux:cmake')));
        expect(plan.messages.join(), contains('linux'));
      },
    );

    test('are not what a full run of a project with no linux flavors has to '
        'cover, and are what one with them has to', () {
      final config = FlavorizrConfig.parse(android);

      expect(engineIdsFor(registry, config), {
        'android:androidManifest',
        'android:flavorizrGradle',
        'android:buildGradle',
        'android:dummyAssets',
        'android:icons',
        'flutter:flavors',
      });
      expect(engineIdsFor(registry, FlavorizrConfig.parse(linux)), {
        'linux:cmake',
        'linux:runnerCmake',
        'linux:myApplication',
        'flutter:flavors',
      });
    });
  });

  group('the windows processors', () {
    final windows = '''
flavors:
  apple:
    app:
      name: "Apple"
    windows: {}
''';

    test('all run on the engine, the icons after the placeholders', () {
      final plan = resolve(windows, ['windows']);

      expect(
        engine(plan),
        unorderedEquals([
          'windows:mainCppTemplate',
          'windows:runnerRcTemplate',
          'windows:cmake',
          'windows:dummyAssets',
          'windows:icons',
        ]),
      );
      expect(
        engine(plan).indexOf('windows:dummyAssets'),
        lessThan(engine(plan).indexOf('windows:icons')),
      );
      expect(
        engine(plan).indexOf('windows:runnerRcTemplate'),
        lessThan(engine(plan).indexOf('windows:cmake')),
      );
      expect(plan.paths, {
        'windows/runner/main.cpp.in',
        'windows/runner/Runner.rc.in',
        'windows/runner/CMakeLists.txt',
        'windows/runner/resources',
      });
    });

    test('are left out of the default run of a project with no windows '
        'flavors', () {
      final plan = resolve(android);

      expect(engine(plan), isNot(contains('windows:cmake')));
      expect(plan.messages.join(), contains('windows'));
    });

    test('are not what a full run of a project with no windows flavors has '
        'to cover, and are what one with them has to', () {
      expect(
        engineIdsFor(registry, FlavorizrConfig.parse(android)),
        isNot(contains('windows:cmake')),
      );
      expect(engineIdsFor(registry, FlavorizrConfig.parse(windows)), {
        'windows:mainCppTemplate',
        'windows:runnerRcTemplate',
        'windows:cmake',
        'windows:dummyAssets',
        'windows:icons',
        'flutter:flavors',
      });
    });
  });
}
