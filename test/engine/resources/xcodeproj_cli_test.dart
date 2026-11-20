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

import 'package:flutter_flavorizr/src/engine/resources/xcodeproj_resource.dart';
import 'package:flutter_flavorizr/src/entrypoint/cli_context.dart';
import 'package:flutter_flavorizr/src/entrypoint/exit_codes.dart';
import 'package:flutter_flavorizr/src/entrypoint/processor_registry.dart';
import 'package:flutter_flavorizr/src/processors/darwin/darwin_add_file_processor.dart';
import 'package:flutter_flavorizr/src/entrypoint/run.dart' as cli;
import 'package:test/test.dart';
import 'package:path/path.dart' as p;

import '../../entrypoint/cli_fixture.dart';
import 'xcodeproj_fixture.dart';

const _pbxproj = 'ios/Runner.xcodeproj/project.pbxproj';

void main() {
  late CliFixture project;
  late List<String> saves;
  late Object? failure;
  late List<String> files;
  late Map<String, String Function(String source)> owned;

  /// The CLI of the project, with processors that require the iOS project.
  Future<int> run(List<String> args) {
    final context = CliContext(
      projectRoot: project.root,
      logger: project.logger,
      terminal: NoTerminal(),
      version: '3.0.0',
      registry: ProcessorRegistry(
        engine: [
          EngineProcessor(
            XcodeprojTestProcessor(
              'test:ios',
              XcodeprojResource.iosKey,
              XcodeprojResource.iosArtifact,
              (xcodeproj) {
                for (final file in files) {
                  DarwinAddFileProcessor.addTo(xcodeproj, file);
                }
              },
              error: failure,
            ),
            // The project is not among its paths: the resource brings it.
            paths: const {},
          ),
        ],
        resources: [
          EngineResource(
            XcodeprojResource.ios(
              save: (xcodeproj) {
                saves.add('ios');

                return xcodeproj.save();
              },
            ),
            paths: const {XcodeprojResource.iosProject},
            ownedContent: owned,
          ),
        ],
      ),
    );

    return cli.run(args, context: context);
  }

  setUp(() {
    project = CliFixture(android: false);
    saves = [];
    failure = null;
    files = ['one.xcconfig'];
    owned = {};

    final source = File('test_resources/example_2x/$_pbxproj');
    project.write(_pbxproj, source.readAsStringSync());
  });
  tearDown(() => project.dispose());

  group('the Xcode project of a run', () {
    test('is not written by plan, a dry run', () async {
      final before = project.read(_pbxproj);

      final code = await run(['plan', 'test:ios']);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.logger.output, contains('~ $_pbxproj'));
      // It was saved, in the shadow workspace: that is what the preview shows.
      expect(saves, ['ios']);
      expect(project.read(_pbxproj), before);
      expect(project.exists('flavorizr.lock'), isFalse);
    });

    test('is saved once by apply, and the lock follows', () async {
      final before = project.read(_pbxproj);

      final code = await run(['apply', '--yes', 'test:ios']);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(saves, ['ios']);
      expect(project.read(_pbxproj), isNot(before));
      expect(project.read(_pbxproj), contains('one.xcconfig'));
      expect(project.read('flavorizr.lock'), contains(_pbxproj));
    });

    test(
      'is left byte identical by a second apply, which saves nothing',
      () async {
        await run(['apply', '--yes', 'test:ios']);

        final after = File(p.join(project.root.path, _pbxproj));
        final bytes = after.readAsBytesSync();
        final modified = after.lastModifiedSync();
        saves.clear();

        final code = await run(['apply', '--yes', 'test:ios']);

        expect(code, ExitCodes.ok, reason: project.logger.output);
        expect(saves, isEmpty);
        expect(after.readAsBytesSync(), bytes);
        expect(after.lastModifiedSync(), modified);
      },
    );

    test('is not written, nor is the lock, when a processor fails', () async {
      failure = StateError('boom');
      final before = project.read(_pbxproj);

      final code = await run(['apply', '--yes', 'test:ios']);

      expect(code, isNot(ExitCodes.ok));
      expect(saves, isEmpty);
      expect(project.read(_pbxproj), before);
      expect(project.exists('flavorizr.lock'), isFalse);
    });

    /// An edit of the project that is nobody's business but Xcode's.
    void editElsewhere() => project.write(
      _pbxproj,
      project
          .read(_pbxproj)
          .replaceFirst('LastUpgradeCheck = 1510;', 'LastUpgradeCheck = 1600;'),
    );

    // KNOWN LIMITATION: until a processor says which part of the project it
    // owns (#515), the lock hashes `project.pbxproj` whole.
    test('reports a conflict on an edit elsewhere in the file, as the lock '
        'hashes the whole project by default', () async {
      await run(['apply', '--yes', 'test:ios']);
      editElsewhere();
      files = ['one.xcconfig', 'two.xcconfig'];

      final code = await run(['apply', '--yes', 'test:ios']);

      expect(code, ExitCodes.attention, reason: project.logger.output);
      expect(project.read(_pbxproj), isNot(contains('two.xcconfig')));
    });

    test('does not mind an edit elsewhere in the file when its owner hashes '
        'only what it owns', () async {
      // The stand-in for an owned part: the lines of the files it adds.
      owned = {
        _pbxproj: (source) => source
            .split('\n')
            .where((line) => line.contains('.xcconfig in Resources'))
            .join('\n'),
      };
      await run(['apply', '--yes', 'test:ios']);
      editElsewhere();
      files = ['one.xcconfig', 'two.xcconfig'];

      final code = await run(['apply', '--yes', 'test:ios']);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.read(_pbxproj), contains('two.xcconfig'));
      expect(project.read(_pbxproj), contains('LastUpgradeCheck = 1600;'));
    });

    test(
      'still reports a conflict on an edit of what its owner hashes',
      () async {
        owned = {
          _pbxproj: (source) => source
              .split('\n')
              .where((line) => line.contains('.xcconfig in Resources'))
              .join('\n'),
        };
        await run(['apply', '--yes', 'test:ios']);
        project.write(
          _pbxproj,
          project
              .read(_pbxproj)
              .replaceFirst(
                'one.xcconfig in Resources',
                'edited.xcconfig in Resources',
              ),
        );
        files = ['one.xcconfig', 'two.xcconfig'];

        final code = await run(['apply', '--yes', 'test:ios']);

        expect(code, ExitCodes.attention, reason: project.logger.output);
      },
    );
  });
}
