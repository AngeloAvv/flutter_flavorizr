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
import 'package:image/image.dart' as img;
import 'package:test/test.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

import '../test_utils.dart';

void main() {
  final config = FlavorizrConfig.parse('''
flavors:
  apple:
    app:
      name: Apple
    android:
      applicationId: com.example.apple
    ios:
      bundleId: com.example.apple
      icon: assets/icon.png
''');

  /// What `ios:icons` writes for the flavor, which is a file of the engine in
  /// some tests and a file a 2.x processor writes in the others.
  const contents =
      'ios/Runner/Assets.xcassets/AppIcon-apple.appiconset/Contents.json';
  const icon20 =
      'ios/Runner/Assets.xcassets/AppIcon-apple.appiconset/Icon-App-20x20@2x.png';

  void writeIcon() => File('assets/icon.png')
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(img.encodePng(img.Image(width: 16, height: 16)));

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
      final logger = _ProgressCountingLogger();

      addTearDown(() {
        Directory.current = previous;
        project.deleteSync(recursive: true);
      });
      Directory.current = project;
      writeIcon();

      await StandardLegacyPipeline(project).run(
        [LegacyStep('ios:icons', config)],
        logger: logger,
        observer: observer,
      );

      expect(observer.events, ['started ios:icons', 'finished ios:icons']);
      expect(logger.progresses, 0, reason: 'the observer shows the step');
    });
  });

  group('an observer that throws', () {
    late Directory project;
    late Directory previous;

    String placed() =>
        File(p.join(project.path, contents)).existsSync().toString();

    setUp(() {
      project = Directory.systemTemp.createTempSync('flavorizr_throwing_');
      previous = Directory.current;
      Directory.current = project;
      writeIcon();
    });

    tearDown(() {
      Directory.current = previous;
      project.deleteSync(recursive: true);
    });

    Future<void> run(StepObserver observer) =>
        StandardLegacyPipeline(project).run(
          [LegacyStep('ios:icons', config), LegacyStep('ios:icons', config)],
          logger: TestUtils.quietLogger(),
          observer: observer,
        );

    test('does not skip the step it was told about', () async {
      final observer = _ThrowingObserver('started');

      await run(observer);

      expect(placed(), 'true');
      expect(observer.finishes, 2, reason: 'both steps ran, once each');
    });

    test('does not stop the steps that follow a step that went well', () async {
      final observer = _ThrowingObserver('finished');

      await run(observer);

      expect(observer.starts, 2);
      expect(
        observer.failures,
        0,
        reason: 'a step that went well did not fail',
      );
    });

    test('does not replace the error of the step that failed', () async {
      await expectLater(
        StandardLegacyPipeline(Directory.current).run(
          [LegacyStep('nope:nope', config)],
          logger: TestUtils.quietLogger(),
          observer: _ThrowingObserver('failed'),
        ),
        throwsA(isA<UnknownProcessorException>()),
      );
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
      writeIcon();
      // What the engine generated for the flavor.
      write(contents, 'ENGINE');
    });

    tearDown(() {
      Directory.current = previous;
      project.deleteSync(recursive: true);
    });

    Future<void> icons(Set<String> preserve) =>
        StandardLegacyPipeline(project).run(
          [LegacyStep('ios:icons', config)],
          logger: TestUtils.quietLogger(),
          preserve: preserve,
        );

    test('a file of the engine survives what a step writes over it', () async {
      await icons({contents});

      expect(read(contents), 'ENGINE');
    });

    test('the rest of what the step writes still reaches the flavor', () async {
      await icons({contents});

      expect(File(p.join(project.path, icon20)).existsSync(), isTrue);
    });

    test('without it the step wins, which is the 2.x order reversed', () async {
      await icons({});

      expect(read(contents), contains('"images"'));
    });

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

      await icons({'android/app/flavorizr.gradle'});

      expect(read('android/app/flavorizr.gradle'), 'GRADLE');
    }, skip: Platform.isWindows ? 'needs POSIX permissions' : false);

    test('a path that did not exist is not created', () async {
      await icons({
        'ios/Runner/Assets.xcassets/AppIcon-apple.appiconset/no.png',
      });

      expect(
        File(
          p.join(
            project.path,
            'ios/Runner/Assets.xcassets/AppIcon-apple.appiconset/no.png',
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

/// A logger that counts the progress bars it is asked for.
class _ProgressCountingLogger extends Logger {
  int progresses = 0;

  _ProgressCountingLogger() : super(level: Level.quiet);

  @override
  Progress progress(String message, {ProgressOptions? options}) {
    progresses++;

    return super.progress(message, options: options);
  }
}

/// An observer that throws when told about [on], as an output whose stdout was
/// closed would, and counts what reached it.
class _ThrowingObserver implements StepObserver {
  final String on;
  int starts = 0;
  int finishes = 0;
  int failures = 0;

  _ThrowingObserver(this.on);

  @override
  void started(String id) {
    starts++;
    if (on == 'started') throw StateError('stdout is closed');
  }

  @override
  void finished(String id, Duration elapsed) {
    finishes++;
    if (on == 'finished') throw StateError('stdout is closed');
  }

  @override
  void failed(String id, Duration elapsed, Object error) {
    failures++;
    if (on == 'failed') throw StateError('stdout is closed');
  }
}
