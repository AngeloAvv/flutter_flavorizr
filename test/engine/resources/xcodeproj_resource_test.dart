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

import 'package:dart_xcodeproj/dart_xcodeproj.dart';
import 'package:flutter_flavorizr/src/engine/artifact.dart';
import 'package:flutter_flavorizr/src/engine/execution_plan.dart';
import 'package:flutter_flavorizr/src/engine/flavorizr_processor.dart';
import 'package:flutter_flavorizr/src/engine/plan_executor.dart';
import 'package:flutter_flavorizr/src/engine/resources/xcodeproj_resource.dart';
import 'package:flutter_flavorizr/src/engine/shadow/file_digest.dart';
import 'package:flutter_flavorizr/src/exception/file_not_found_exception.dart';
import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../test_utils.dart';
import 'xcodeproj_fixture.dart';

const _iosPbxproj = 'ios/Runner.xcodeproj/project.pbxproj';
const _macosPbxproj = 'macos/Runner.xcodeproj/project.pbxproj';

void main() {
  late Directory project;
  late List<String> events;
  late XcodeprojResource ios;
  late XcodeprojResource macos;

  File file(String path) => File(p.join(project.path, path));

  void copyProject(String platform) {
    final source = Directory('example/$platform/Runner.xcodeproj');
    final target = Directory(p.join(project.path, platform, 'Runner.xcodeproj'))
      ..createSync(recursive: true);

    File(
      p.join(source.path, 'project.pbxproj'),
    ).copySync(p.join(target.path, 'project.pbxproj'));
  }

  XcodeprojTestProcessor onIos(
    String id,
    void Function(XcodeProject project) mutate, {
    Object? error,
    Set<String> after = const {},
  }) => XcodeprojTestProcessor(
    id,
    XcodeprojResource.iosKey,
    XcodeprojResource.iosArtifact,
    mutate,
    error: error,
    after: after,
  );

  XcodeprojTestProcessor onMacos(
    String id,
    void Function(XcodeProject project) mutate,
  ) => XcodeprojTestProcessor(
    id,
    XcodeprojResource.macosKey,
    XcodeprojResource.macosArtifact,
    mutate,
  );

  /// Applies [processors] to the project and copies the result back, like a
  /// run that is approved.
  Future<ExecutionReport> run(List<FlavorizrProcessor> processors) {
    return PlanExecutor(logger: TestUtils.quietLogger()).execute(
      resolveExecutionPlan(processors, requested: processors.map((p) => p.id)),
      config: Flavorizr.parse(
        'flavors:\n  apple:\n    app:\n      name: apple\n'
        '    ios:\n      bundleId: com.example.apple\n',
      ),
      projectRoot: project,
      paths: [XcodeprojResource.iosProject, XcodeprojResource.macosProject],
      resources: [ios, macos],
      commit: (shadow, ctx) async {
        final diff = await shadow.diff(
          tracked: ctx.tracked,
          recordedHashes: const {},
          hasher: (_, bytes) => digestOf(bytes),
        );

        await shadow.copyBack(diff);
      },
    );
  }

  setUp(() {
    final temp = Directory.systemTemp.createTempSync('flavorizr_xcodeproj_');
    addTearDown(() => temp.deleteSync(recursive: true));

    project = Directory(p.join(temp.path, 'project'))..createSync();
    copyProject('ios');
    copyProject('macos');
    events = [];

    Future<XcodeProject> open(String path, String name) {
      events.add('open $name');

      return XcodeProject.open(path);
    }

    ios = XcodeprojResource.ios(
      open: (path) => open(path, 'ios'),
      save: (project) {
        events.add('save ios');

        return project.save();
      },
    );
    macos = XcodeprojResource.macos(
      open: (path) => open(path, 'macos'),
      save: (project) {
        events.add('save macos');

        return project.save();
      },
    );
  });

  group('XcodeprojResource', () {
    test('has one key per platform', () {
      expect(XcodeprojResource.iosKey.name, 'xcodeproj:ios');
      expect(XcodeprojResource.macosKey.name, 'xcodeproj:macos');
      expect(ios.key, XcodeprojResource.iosKey);
      expect(macos.key, XcodeprojResource.macosKey);
    });

    test('declares the project folder and the patched project file', () {
      expect(XcodeprojResource.iosProject, 'ios/Runner.xcodeproj');
      expect(XcodeprojResource.macosProject, 'macos/Runner.xcodeproj');
      expect(
        XcodeprojResource.iosArtifact,
        const Artifact.patched(_iosPbxproj),
      );
      expect(
        XcodeprojResource.macosArtifact,
        const Artifact.patched(_macosPbxproj),
      );
    });

    test('opens the project once and hands the same instance to every '
        'consumer', () async {
      final first = onIos('test:first', (project) {});
      final second = onIos('test:second', (project) {}, after: {'test:first'});
      final third = onIos('test:third', (project) {}, after: {'test:second'});

      final report = await run([first, second, third]);

      expect(report.succeeded, isTrue, reason: report.render());
      expect(events, ['open ios']);
      expect(second.seen, same(first.seen));
      expect(third.seen, same(first.seen));
    });

    test('does not open the project of a platform nobody requires', () async {
      File(p.join(project.path, 'macos')).deleteSync(recursive: true);

      final report = await run([onIos('test:first', (project) {})]);

      expect(report.succeeded, isTrue, reason: report.render());
      expect(events, ['open ios']);
    });

    test(
      'saves once, after the last consumer, when the project changed',
      () async {
        final before = file(_iosPbxproj).readAsStringSync();

        final report = await run([
          onIos(
            'test:first',
            (project) => addFileReference(project, 'one.xcconfig'),
          ),
          onIos(
            'test:second',
            (project) => addFileReference(project, 'two.xcconfig'),
            after: {'test:first'},
          ),
        ]);

        expect(report.succeeded, isTrue, reason: report.render());
        expect(events, ['open ios', 'save ios']);

        final after = file(_iosPbxproj).readAsStringSync();
        expect(after, isNot(before));
        expect(after, contains('one.xcconfig'));
        expect(after, contains('two.xcconfig'));
      },
    );

    test(
      'leaves the project byte identical when a run changes nothing',
      () async {
        final before = file(_iosPbxproj).readAsBytesSync();
        final modified = file(_iosPbxproj).lastModifiedSync();

        final report = await run([
          onIos('test:read', (project) => project.targets.first.name),
          onIos(
            'test:rewrite',
            // The same values, written again: a second run does just that.
            (project) {
              final settings =
                  project.targets.first.buildConfigurations.first.buildSettings;

              settings.addAll(Map.of(settings));
            },
            after: {'test:read'},
          ),
        ]);

        expect(report.succeeded, isTrue, reason: report.render());
        expect(events, ['open ios']);
        expect(file(_iosPbxproj).readAsBytesSync(), before);
        expect(file(_iosPbxproj).lastModifiedSync(), modified);
      },
    );

    test('does not save a project that is changed and changed back', () async {
      final before = file(_iosPbxproj).readAsBytesSync();

      final report = await run([
        onIos('test:there', (project) {
          final settings =
              project.targets.first.buildConfigurations.first.buildSettings;
          settings['FLAVORIZR_TMP'] = 'x';
        }),
        onIos('test:back', (project) {
          project.targets.first.buildConfigurations.first.buildSettings.remove(
            'FLAVORIZR_TMP',
          );
        }, after: {'test:there'}),
      ]);

      expect(report.succeeded, isTrue, reason: report.render());
      expect(events, ['open ios']);
      expect(file(_iosPbxproj).readAsBytesSync(), before);
    });

    test('notices a change made in place to a value the project already '
        'holds', () async {
      final before = file(_iosPbxproj).readAsStringSync();

      final report = await run([
        onIos('test:inplace', (project) {
          project
                  .targets
                  .first
                  .buildConfigurations
                  .first
                  .buildSettings['FLAVORIZR_IN_PLACE'] =
              'yes';
        }),
      ]);

      expect(report.succeeded, isTrue, reason: report.render());
      expect(events, ['open ios', 'save ios']);
      expect(file(_iosPbxproj).readAsStringSync(), isNot(before));
      expect(
        file(_iosPbxproj).readAsStringSync(),
        contains('FLAVORIZR_IN_PLACE'),
      );
    });

    test('notices a change of order', () async {
      final report = await run([
        onIos('test:reorder', (project) {
          final children = project.mainGroup.children;
          final first = children.first;
          children.remove(first);
          children.add(first);
        }),
      ]);

      expect(report.succeeded, isTrue, reason: report.render());
      expect(events, ['open ios', 'save ios']);
    });

    test('saves nothing when a later processor fails', () async {
      final before = file(_iosPbxproj).readAsBytesSync();

      final report = await run([
        onIos(
          'test:first',
          (project) => addFileReference(project, 'one.xcconfig'),
        ),
        onIos(
          'test:second',
          (project) => addFileReference(project, 'two.xcconfig'),
          error: StateError('boom'),
          after: {'test:first'},
        ),
      ]);

      expect(report.succeeded, isFalse);
      expect(report.failed, 'test:second');
      expect(events, ['open ios']);
      expect(file(_iosPbxproj).readAsBytesSync(), before);
    });

    test('saves nothing when the processor that changed it is the one that '
        'fails', () async {
      final before = file(_iosPbxproj).readAsBytesSync();

      final report = await run([
        onIos(
          'test:only',
          (project) => addFileReference(project, 'one.xcconfig'),
          error: StateError('boom'),
        ),
      ]);

      expect(report.succeeded, isFalse);
      expect(events, ['open ios']);
      expect(file(_iosPbxproj).readAsBytesSync(), before);
    });

    test('keeps the two platforms apart: one saves, the other stays byte '
        'identical', () async {
      final macosBefore = file(_macosPbxproj).readAsBytesSync();
      final iosBefore = file(_iosPbxproj).readAsStringSync();

      final report = await run([
        onIos(
          'test:ios',
          (project) => addFileReference(project, 'one.xcconfig'),
        ),
        onMacos('test:macos', (project) => project.targets.first.name),
      ]);

      expect(report.succeeded, isTrue, reason: report.render());
      expect(events, unorderedEquals(['open ios', 'open macos', 'save ios']));
      expect(file(_iosPbxproj).readAsStringSync(), isNot(iosBefore));
      expect(file(_macosPbxproj).readAsBytesSync(), macosBefore);
    });

    test('saves both platforms, once each, when both changed', () async {
      final report = await run([
        onIos(
          'test:ios',
          (project) => addFileReference(project, 'one.xcconfig'),
        ),
        onMacos(
          'test:macos',
          (project) => addFileReference(project, 'one.xcconfig'),
        ),
      ]);

      expect(report.succeeded, isTrue, reason: report.render());
      expect(
        events,
        unorderedEquals(['open ios', 'open macos', 'save ios', 'save macos']),
      );
    });

    test(
      'fails the run, with the project untouched, when the save fails',
      () async {
        final failing = XcodeprojResource.ios(
          save: (project) async => throw const FileSystemException('disk full'),
        );
        final before = file(_iosPbxproj).readAsBytesSync();

        final report = await PlanExecutor(logger: TestUtils.quietLogger())
            .execute(
              resolveExecutionPlan(
                [
                  onIos(
                    'test:ios',
                    (project) => addFileReference(project, 'a.xcconfig'),
                  ),
                ],
                requested: ['test:ios'],
              ),
              config: Flavorizr.parse(
                'flavors:\n  apple:\n    app:\n      name: apple\n'
                '    ios:\n      bundleId: com.example.apple\n',
              ),
              projectRoot: project,
              paths: [XcodeprojResource.iosProject],
              resources: [failing],
              commit: (shadow, ctx) async => fail('must not commit'),
            );

        expect(report.succeeded, isFalse);
        expect(report.error, isA<FileSystemException>());
        expect(file(_iosPbxproj).readAsBytesSync(), before);
      },
    );

    test(
      'fails with the missing file when the project does not exist',
      () async {
        File(p.join(project.path, 'ios')).deleteSync(recursive: true);
        Directory(p.join(project.path, 'ios')).createSync();

        final report = await run([onIos('test:ios', (project) {})]);

        expect(report.succeeded, isFalse);
        expect(report.error, isA<FileNotFoundException>());
        expect(
          report.error.toString(),
          contains('ios/Runner.xcodeproj/project.pbxproj'),
        );
        expect(events, isEmpty);
      },
    );

    test(
      'is not shared between runs: a resource opens afresh every time',
      () async {
        await run([
          onIos('test:a', (project) => addFileReference(project, 'a.xcconfig')),
        ]);
        await run([
          onIos('test:b', (project) => addFileReference(project, 'a.xcconfig')),
        ]);

        // The second run found the file reference the first one saved: no change.
        expect(events, ['open ios', 'save ios', 'open ios']);
      },
    );

    test(
      'writes only in the shadow workspace until the run is committed',
      () async {
        final before = file(_iosPbxproj).readAsBytesSync();

        final report = await PlanExecutor(logger: TestUtils.quietLogger())
            .execute(
              resolveExecutionPlan(
                [
                  onIos(
                    'test:ios',
                    (project) => addFileReference(project, 'a.xcconfig'),
                  ),
                ],
                requested: ['test:ios'],
              ),
              config: Flavorizr.parse(
                'flavors:\n  apple:\n    app:\n      name: apple\n'
                '    ios:\n      bundleId: com.example.apple\n',
              ),
              projectRoot: project,
              paths: [XcodeprojResource.iosProject],
              resources: [ios],
              // A dry run: the changes are found out and nothing is copied back.
              commit: (shadow, ctx) async {
                final diff = await shadow.diff(
                  tracked: ctx.tracked,
                  recordedHashes: const {},
                  hasher: (_, bytes) => digestOf(bytes),
                );

                expect(diff.changes.map((change) => change.describe()), [
                  '~ $_iosPbxproj (patched)',
                ]);
              },
            );

        expect(report.succeeded, isTrue, reason: report.render());
        expect(events, ['open ios', 'save ios']);
        expect(file(_iosPbxproj).readAsBytesSync(), before);
      },
    );
  });
}
