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

import 'package:test/test.dart';

import 'adopt_fixture.dart';
import 'cli_fixture.dart';

const _iosProject = 'ios/Runner.xcodeproj/project.pbxproj';
const _macosProject = 'macos/Runner.xcodeproj/project.pbxproj';

/// The UUIDs of the objects of a project file whose comment is `<Mode>-<flavor>`
/// (the build configurations 2.x made) or the path of an xcconfig of the
/// flavor, as 2.x left them.
Set<String> _uuidsOf(String pbxproj, RegExp comment) => {
  for (final match in RegExp(
    r'^\t\t([0-9A-F]{24}) /\* ([^*]+?) \*/ = \{',
    multiLine: true,
  ).allMatches(pbxproj))
    if (comment.hasMatch(match.group(2)!)) match.group(1)!,
};

final _configurations = RegExp(r'^(Debug|Profile|Release)-(apple|banana)$');
final _xcconfigs = RegExp(r'(apple|banana)(Debug|Profile|Release)\.xcconfig$');

void main() {
  late CliFixture project;

  setUp(() => project = project2x());
  tearDown(() => project.dispose());

  group('adopt, the Xcode projects', () {
    test('records the UUIDs of the build configurations and of the xcconfig '
        'references 2.x made, as they are', () async {
      final before = project.read(_iosProject);
      final configurations = _uuidsOf(before, _configurations);
      final references = _uuidsOf(before, _xcconfigs);

      expect(configurations, hasLength(12));
      expect(references, hasLength(6));

      expect(await project.run(['adopt']), 0, reason: project.logger.output);

      final lock = (await lockOf(project))!;

      expect(
        lock.processors['ios:buildTargets']!.objects[_iosProject],
        containsAll(configurations),
      );
      expect(
        lock.processors['ios:xcconfig']!.objects[_iosProject],
        containsAll(references),
      );
      expect(project.read(_iosProject), before);
    });

    test('records the ones of macOS too', () async {
      final configurations = _uuidsOf(
        project.read(_macosProject),
        _configurations,
      );

      expect(configurations, hasLength(12));
      expect(await project.run(['adopt']), 0, reason: project.logger.output);

      final lock = (await lockOf(project))!;

      expect(
        lock.processors['macos:buildTargets']!.objects[_macosProject],
        containsAll(configurations),
      );
    });

    test('does not record an object the project does not have: what 3.x '
        'would make is created by apply', () async {
      final text = project.read(_iosProject);
      final lock = await () async {
        await project.run(['adopt']);

        return (await lockOf(project))!;
      }();
      final recorded = {
        for (final processor in lock.processors.values)
          ...?processor.objects[_iosProject],
      };

      expect(recorded.where((uuid) => !text.contains(uuid)), isEmpty);
    });

    test('records the build settings 2.x wrote as they are, and the run that '
        'follows does not take them for edits', () async {
      await project.run(['adopt']);

      final text = project.read(_iosProject);
      final keys = (await lockOf(
        project,
      ))!.processors['ios:buildTargets']!.keys[_iosProject]!;

      expect(keys, isNotEmpty);
      expect(
        keys.keys.where((key) => !text.contains(key.split('/')[1])),
        isEmpty,
      );
      expect(
        await project.run(['apply', '--yes']),
        0,
        reason: project.logger.output,
      );
    });

    test('is followed by an apply that keeps the objects 2.x made, with the '
        'UUIDs they have, and makes no second one', () async {
      final before = project.read(_iosProject);
      final configurations = _uuidsOf(before, _configurations);

      await project.run(['adopt']);

      expect(
        await project.run(['apply', '--yes']),
        0,
        reason: project.logger.output,
      );

      final after = project.read(_iosProject);

      expect(_uuidsOf(after, _configurations), configurations);
      expect(
        RegExp('name = "Debug-apple";').allMatches(after),
        hasLength(RegExp('name = "Debug-apple";').allMatches(before).length),
      );
      expect(
        RegExp(r'path = "?Flutter/appleDebug\.xcconfig').allMatches(after),
        hasLength(1),
      );
    });

    test('lets the next run remove what 2.x made for a flavor that is dropped, '
        'and nothing else', () async {
      await project.run(['adopt']);
      await project.run(['apply', '--yes']);

      expect(project.read(_iosProject), contains('Debug-banana'));

      final yaml = project.read('flavorizr.yaml');

      project.write(
        'flavorizr.yaml',
        yaml.replaceRange(
          yaml.indexOf('  banana:'),
          yaml.indexOf('ide:'),
          '\n',
        ),
      );

      expect(
        await project.run(['apply', '--yes']),
        0,
        reason: project.logger.output,
      );

      for (final path in [_iosProject, _macosProject]) {
        final after = project.read(path);

        expect(after, isNot(contains('-banana')), reason: path);
        expect(after, isNot(contains('banana.xcconfig')), reason: path);
        expect(after, isNot(matches(RegExp(r'banana(Debug|Profile|Release)'))));
        expect(after, contains('Debug-apple'), reason: path);
      }
    });
  });

  group('adopt, the launch screens of 2.x', () {
    const storyboard = 'ios/Runner/appleLaunchScreen.storyboard';
    const imageset = 'ios/Runner/Assets.xcassets/appleLaunchImage.imageset';

    test(
      'are the user\'s: told, never recorded, and no run deletes them',
      () async {
        expect(project.exists(storyboard), isTrue);
        expect(project.exists('$imageset/Contents.json'), isTrue);

        expect(await project.run(['adopt']), 0, reason: project.logger.output);

        final lock = (await lockOf(project))!;
        final recorded = {
          for (final processor in lock.processors.values)
            ...processor.files.keys,
        };

        expect(
          recorded.where((path) => path.contains('LaunchScreen')),
          isEmpty,
        );
        expect(recorded.where((path) => path.contains('LaunchImage')), isEmpty);
        expect(
          project.logger.output,
          contains('Yours, left alone: $storyboard'),
        );
        expect(
          project.logger.output,
          contains('Yours, left alone: $imageset/'),
        );

        final changes = await planned(project);

        expect(
          changes.keys.where((path) => path.contains('Launch')),
          isEmpty,
          reason: '$changes',
        );

        // Not even when the flavor goes.
        final yaml = project.read('flavorizr.yaml');

        project.write(
          'flavorizr.yaml',
          yaml.replaceRange(
            yaml.indexOf('  apple:'),
            yaml.indexOf('  banana:'),
            '',
          ),
        );

        expect(
          await project.run(['apply', '--yes']),
          0,
          reason: project.logger.output,
        );
        expect(project.exists(storyboard), isTrue);
        expect(project.exists('$imageset/Contents.json'), isTrue);
      },
    );

    test('are told for the flavors of --flavors too', () async {
      project.write('ios/Runner/cherryLaunchScreen.storyboard', '<document/>');

      expect(
        await project.run(['adopt', '--flavors', 'cherry']),
        0,
        reason: project.logger.output,
      );
      expect(
        project.logger.output,
        contains('Yours, left alone: ios/Runner/cherryLaunchScreen.storyboard'),
      );
      expect(
        project.exists('ios/Runner/cherryLaunchScreen.storyboard'),
        isTrue,
      );
    });

    test(
      'are not looked for when the iOS processors are not adopted',
      () async {
        expect(
          await project.run(['adopt', 'android:icons']),
          0,
          reason: project.logger.output,
        );
        expect(project.logger.output, isNot(contains('LaunchScreen')));
      },
    );
  });
}
