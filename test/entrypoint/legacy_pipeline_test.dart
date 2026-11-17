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

import 'package:flutter_flavorizr/src/engine/step_observer.dart';
import 'package:flutter_flavorizr/src/entrypoint/legacy_pipeline.dart';
import 'package:flutter_flavorizr/src/exception/unknown_processor_exception.dart';
import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../test_utils.dart';
import 'cli_fixture.dart';

void main() {
  final config = Flavorizr.parse(CliFixture.config(['apple']));

  test('refuses to run on a project that is not the working directory', () {
    final elsewhere = Directory.systemTemp.createTempSync('flavorizr_legacy_');
    addTearDown(() => elsewhere.deleteSync(recursive: true));

    expect(
      () => StandardLegacyPipeline(elsewhere).run([
        LegacyStep('ide:config', config),
      ], logger: TestUtils.quietLogger()),
      throwsStateError,
    );
  });

  test('does nothing, anywhere, when there is nothing to run', () async {
    final elsewhere = Directory.systemTemp.createTempSync('flavorizr_legacy_');
    addTearDown(() => elsewhere.deleteSync(recursive: true));

    await StandardLegacyPipeline(
      elsewhere,
    ).run(const [], logger: TestUtils.quietLogger());
  });

  test('stops at the first instruction that fails', () async {
    await expectLater(
      StandardLegacyPipeline(Directory.current).run([
        LegacyStep('nope:nope', config),
        LegacyStep('ide:config', config),
      ], logger: TestUtils.quietLogger()),
      throwsA(isA<UnknownProcessorException>()),
    );
  });

  group('the observer', () {
    test('is told that a step failed, and the error goes on', () async {
      final observer = _RecordingObserver();

      await expectLater(
        StandardLegacyPipeline(Directory.current).run(
          [LegacyStep('nope:nope', config)],
          logger: TestUtils.quietLogger(),
          observer: observer,
        ),
        throwsA(isA<UnknownProcessorException>()),
      );

      expect(observer.events, ['started nope:nope', 'failed nope:nope']);
    });

    test('is told about a step that went well, which shows nothing', () async {
      final project = Directory.systemTemp.createTempSync(
        'flavorizr_observer_',
      );
      final previous = Directory.current;
      final observer = _RecordingObserver();

      addTearDown(() {
        Directory.current = previous;
        project.deleteSync(recursive: true);
      });
      Directory.current = project;
      File(p.join(project.path, '.tmp/android/res/values/custom.xml'))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('<resources/>');

      await StandardLegacyPipeline(project).run(
        [LegacyStep('android:dummyAssets', config)],
        logger: TestUtils.quietLogger(),
        observer: observer,
      );

      expect(observer.events, [
        'started android:dummyAssets',
        'finished android:dummyAssets',
      ]);
    });
  });

  group('preserve', () {
    late Directory project;
    late Directory previous;

    String read(String path) =>
        File(p.join(project.path, path)).readAsStringSync();

    void write(String path, String content) => File(p.join(project.path, path))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(content);

    setUp(() {
      project = Directory.systemTemp.createTempSync('flavorizr_preserve_');
      previous = Directory.current;
      Directory.current = project;
      // What the assets hold, a custom `assetsUrl` included.
      write('.tmp/android/res/mipmap-mdpi/ic_launcher.png', 'PLACEHOLDER');
      write('.tmp/android/res/mipmap-hdpi/ic_launcher.png', 'PLACEHOLDER');
      write('.tmp/android/res/values/custom.xml', '<resources/>');
      // What the engine generated for the flavor.
      write('android/app/src/apple/res/mipmap-mdpi/ic_launcher.png', 'ICON');
    });

    tearDown(() {
      Directory.current = previous;
      project.deleteSync(recursive: true);
    });

    Future<void> dummyAssets(Set<String> preserve) =>
        StandardLegacyPipeline(project).run(
          [LegacyStep('android:dummyAssets', config)],
          logger: TestUtils.quietLogger(),
          preserve: preserve,
        );

    test('a file of the engine survives what is copied over it', () async {
      await dummyAssets({
        'android/app/src/apple/res/mipmap-mdpi/ic_launcher.png',
      });

      expect(
        read('android/app/src/apple/res/mipmap-mdpi/ic_launcher.png'),
        'ICON',
      );
    });

    test('the rest of the assets still reaches the flavor', () async {
      await dummyAssets({
        'android/app/src/apple/res/mipmap-mdpi/ic_launcher.png',
      });

      expect(
        read('android/app/src/apple/res/mipmap-hdpi/ic_launcher.png'),
        'PLACEHOLDER',
      );
      expect(
        read('android/app/src/apple/res/values/custom.xml'),
        '<resources/>',
      );
    });

    test(
      'without it the placeholder wins, which is the 2.x order reversed',
      () async {
        await dummyAssets({});

        expect(
          read('android/app/src/apple/res/mipmap-mdpi/ic_launcher.png'),
          'PLACEHOLDER',
        );
      },
    );

    test('a file the step did not change is not written again', () async {
      write('android/app/flavorizr.gradle', 'GRADLE');
      Process.runSync('chmod', [
        '444',
        p.join(project.path, 'android/app/flavorizr.gradle'),
      ]);
      addTearDown(
        () => Process.runSync('chmod', [
          '644',
          p.join(project.path, 'android/app/flavorizr.gradle'),
        ]),
      );

      await dummyAssets({'android/app/flavorizr.gradle'});

      expect(read('android/app/flavorizr.gradle'), 'GRADLE');
    }, skip: Platform.isWindows ? 'needs POSIX permissions' : false);

    test('a path that did not exist is not created', () async {
      await dummyAssets({
        'android/app/src/apple/res/mipmap-xhdpi/ic_launcher.png',
      });

      expect(
        File(
          p.join(
            project.path,
            'android/app/src/apple/res/mipmap-xhdpi/ic_launcher.png',
          ),
        ).existsSync(),
        isFalse,
      );
    });
  });
}

class _RecordingObserver implements StepObserver {
  final List<String> events = [];

  @override
  void started(String id) => events.add('started $id');

  @override
  void finished(String id, Duration elapsed) => events.add('finished $id');

  @override
  void failed(String id, Duration elapsed, Object error) =>
      events.add('failed $id');
}
