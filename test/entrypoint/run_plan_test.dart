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
import 'package:flutter_test/flutter_test.dart';

import 'cli_fixture.dart';

void main() {
  final registry = ProcessorRegistry.standard();

  RunPlan resolve(String yaml, [List<String> targets = const []]) =>
      resolveRunPlan(
        registry: registry,
        config: Flavorizr.parse(yaml),
        targets: targets,
      );

  List<String> engine(RunPlan plan) => [
    for (final step in plan.engine.steps)
      '${step.processor.id}${step.auto ? ' (auto)' : ''}',
  ];

  final android = CliFixture.config(['apple']);

  test('splits a recipe between the engine and the legacy pipeline', () {
    final plan = resolve(android, ['android']);

    expect(engine(plan), [
      'android:androidManifest',
      'android:flavorizrGradle',
      'android:buildGradle',
      'android:icons',
    ]);
    expect(plan.legacy.map((step) => step.id), ['android:dummyAssets']);
  });

  test('pulls in what a processor depends on, and says so', () {
    final plan = resolve(android, ['android:buildGradle']);

    expect(engine(plan), [
      'android:flavorizrGradle (auto)',
      'android:buildGradle',
    ]);
    expect(plan.legacy, isEmpty);
  });

  test('the default is the `all` recipe', () {
    final plan = resolve(android);

    expect(engine(plan), hasLength(5));
    expect(plan.legacy.map((step) => step.id), [
      'assets:download',
      'assets:extract',
      'android:dummyAssets',
      'google:firebase',
      'huawei:agconnect',
      'assets:clean',
      'ide:config',
    ]);
  });

  test('leaves out the platforms without flavors, with a message', () {
    final plan = resolve(android, ['android', 'ios']);

    expect(plan.messages, [
      'Skipping "ios": no flavors are configured for ios.',
    ]);
    expect(plan.legacy.map((step) => step.id), ['android:dummyAssets']);
  });

  test('the instructions of the configuration are used without targets', () {
    final plan = resolve(
      '$android'
      'instructions:\n  - android:flavorizrGradle\n  - google:firebase\n',
    );

    expect(engine(plan), ['android:flavorizrGradle']);
    expect(plan.legacy.map((step) => step.id), ['google:firebase']);
  });

  test('instructions that are empty run nothing, like in 2.x', () {
    final plan = resolve('${android}instructions: []\n');

    expect(plan.isEmpty, isTrue);
    expect(plan.engine.steps, isEmpty);
    expect(plan.legacy, isEmpty);
  });

  test('a target wins over empty instructions', () {
    final plan = resolve('${android}instructions: []\n', ['android:icons']);

    expect(engine(plan), ['android:icons']);
  });

  test('a recipe default does not win over empty instructions', () {
    final plan = resolve(
      '${android}instructions: []\nrecipes:\n  ci: [android:icons]\n'
      '  default: ci\n',
    );

    expect(plan.isEmpty, isTrue);
  });

  test('a target wins over the instructions', () {
    final plan = resolve('${android}instructions:\n  - google:firebase\n', [
      'android:icons',
    ]);

    expect(engine(plan), ['android:icons']);
    expect(plan.legacy, isEmpty);
  });

  test('the recipes of the configuration are targets', () {
    final yaml = '${android}recipes:\n  ci: [android:icons, google:firebase]\n';

    final plan = resolve(yaml, ['ci']);

    expect(engine(plan), ['android:icons']);
    expect(plan.legacy.map((step) => step.id), ['google:firebase']);
  });

  test('the default recipe of the configuration runs without targets', () {
    final yaml = '${android}recipes:\n  ci: [android:icons]\n  default: ci\n';

    final plan = resolve(yaml);

    expect(engine(plan), ['android:icons']);
    expect(plan.legacy, isEmpty);
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

  group('dummy assets', () {
    final icons = '''
flavors:
  apple:
    app:
      name: Apple
      icon: assets/apple.png
    android:
      applicationId: com.example.apple
  banana:
    app:
      name: Banana
    android:
      applicationId: com.example.banana
''';

    test('are made for every flavor, the ones with an icon too', () {
      final plan = resolve(icons, ['android']);
      final dummy = plan.legacy.singleWhere(
        (step) => step.id == 'android:dummyAssets',
      );

      // What the engine wrote is kept by the pipeline (see `preserve`), so the
      // rest of what the assets hold reaches every flavor.
      expect(dummy.config.androidFlavors.keys, ['apple', 'banana']);
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

    test('run on the engine, in the order of the recipe, with no legacy '
        'step', () {
      final plan = resolve(linux, ['linux']);

      expect(engine(plan), [
        'linux:cmake',
        'linux:runnerCmake',
        'linux:myApplication',
      ]);
      expect(plan.legacy, isEmpty);
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
      final config = Flavorizr.parse(android);

      expect(engineIdsFor(registry, config), {
        'android:androidManifest',
        'android:flavorizrGradle',
        'android:buildGradle',
        'android:icons',
        'flutter:flavors',
      });
      expect(engineIdsFor(registry, Flavorizr.parse(linux)), {
        'linux:cmake',
        'linux:runnerCmake',
        'linux:myApplication',
        'flutter:flavors',
      });
    });
  });
}
