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

import 'dart:convert';
import 'dart:io';

import 'package:flutter_flavorizr/src/engine/lock/lock_store.dart';
import 'package:flutter_flavorizr/src/engine/processors/darwin/scheme_editor.dart';
import 'package:flutter_flavorizr/src/engine/ownership.dart';
import 'package:flutter_flavorizr/src/entrypoint/exit_codes.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

import '../../../entrypoint/cli_fixture.dart';
import 'flutter_scheme.dart';

const _schemes = 'ios/Runner.xcodeproj/xcshareddata/xcschemes';
const _runner = '$_schemes/Runner.xcscheme';

/// The processors of a run of the iOS schemes.
const _targets = ['flutter:flavors', 'ios:schema'];

/// The target `flutter create` makes, as the example project has it.
const _runnerUuid = '97C146ED1CF9000F007C117D';

String _config({String ios = ''}) => '''
flavors:
  citrus:
    app:
      name: "Citrus App"
    ios:
      bundleId: "com.example.citrus"
  dates:
    app:
      name: "Dates App"
    ios:
      bundleId: "com.example.dates"
$ios''';

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

/// The scripts of the pre-actions of the build action of [scheme].
List<String> _preActionScripts(String scheme) => [
  for (final content in XmlDocument.parse(
    scheme,
  ).rootElement.findAllElements('ActionContent'))
    if (content.parentElement?.parentElement?.name.local == 'PreActions')
      content.getAttribute('scriptText') ?? '',
];

/// The pre-actions of [scheme], as XML without the layout.
List<String> _preActions(String scheme) => [
  for (final element in XmlDocument.parse(scheme).findAllElements('PreActions'))
    (element.copy()
          ..descendants
              .whereType<XmlText>()
              .where((text) => text.value.trim().isEmpty)
              .toList()
              .forEach((text) => text.parent!.children.remove(text)))
        .toXmlString(),
];

/// [source] with [edit] made, which has to change it: an edit that finds
/// nothing to edit would test nothing.
String _edited(String source, String Function(String source) edit) {
  final result = edit(source);

  expect(result, isNot(source));

  return result;
}

void main() {
  late CliFixture project;

  Future<int> apply([List<String> extra = const []]) =>
      project.run(['apply', '--yes', ...extra, ..._targets]);

  /// The scheme of [flavor], once Flutter and Xcode wrote it down.
  String scheme(String flavor) => project.read('$_schemes/$flavor.xcscheme');

  setUp(() {
    project = CliFixture(android: false);
    project.write('flavorizr.yaml', _config());
    project.write(
      'ios/Runner.xcodeproj/project.pbxproj',
      File(
        'test_resources/example_2x/ios/Runner.xcodeproj/project.pbxproj',
      ).readAsStringSync(),
    );
    project.write(
      _runner,
      File(
        'test_resources/example_2x/ios/Runner.xcodeproj/xcshareddata/xcschemes/'
        'Runner.xcscheme',
      ).readAsStringSync(),
    );
  });
  tearDown(() => project.dispose());

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
      'builds the app, and runs and tests the target of the project',
      () async {
        await apply();

        final text = scheme('citrus');

        expect(text, contains('BlueprintIdentifier = "$_runnerUuid"'));
        expect(text, contains('BuildableName = "Runner.app"'));
        expect(
          text,
          contains('ReferencedContainer = "container:Runner.xcodeproj"'),
        );
        expect(text, contains('<BuildActionEntry'));
        expect(text, contains('BuildableName = "RunnerTests.xctest"'));
        expect(text, contains('<BuildableProductRunnable'));
      },
    );

    test('has the pre-action of Flutter when Swift Package Manager is '
        'enabled', () async {
      await apply();

      expect(_preActionScripts(scheme('citrus')), [
        '/bin/sh "\$FLUTTER_ROOT/packages/flutter_tools/bin/xcode_backend.sh" '
            'prepare\n',
      ]);
      // In front of the build entries, as Flutter writes it.
      expect(
        scheme('citrus').indexOf('<PreActions>'),
        lessThan(scheme('citrus').indexOf('<BuildActionEntries>')),
      );
    });

    test(
      'is not touched by Flutter, which finds its pre-action there',
      () async {
        await apply();

        expect(withFlutterPreAction(scheme('citrus')), scheme('citrus'));
      },
    );

    test('has no pre-action when the project disables Swift Package '
        'Manager', () async {
      project.write(
        'pubspec.yaml',
        'name: app\nflutter:\n  config:\n    enable-swift-package-manager: '
            'false\n',
      );

      await apply();

      expect(_preActionScripts(scheme('citrus')), isEmpty);
      expect(_configurations(scheme('citrus'))['LaunchAction'], 'Debug-citrus');
    });

    test('is made again when it is deleted', () async {
      await apply();
      File(project.abs('$_schemes/dates.xcscheme')).deleteSync();

      final code = await apply();

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(
        _configurations(scheme('dates'))['ArchiveAction'],
        'Release-dates',
      );
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
              in lock.processors['ios:schema']!.files.entries)
            path: file.ownership,
        },
        {
          '$_schemes/citrus.xcscheme': Ownership.patched,
          '$_schemes/dates.xcscheme': Ownership.patched,
        },
      );
      expect(project.read(_runner), isNot(contains('Debug-citrus')));
    });
  });

  group('a second run', () {
    test('changes nothing', () async {
      await apply();
      final before = project.snapshot();

      final code = await apply();

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.snapshot(), before);
    });

    test('changes nothing after Flutter injected its pre-action, and is no '
        'conflict', () async {
      project.write(
        'pubspec.yaml',
        'name: app\nflutter:\n  config:\n    enable-swift-package-manager: '
            'false\n',
      );
      await apply();
      // The user turns it on later, and builds: Flutter adds its pre-action.
      for (final flavor in ['citrus', 'dates']) {
        project.write(
          '$_schemes/$flavor.xcscheme',
          withFlutterPreAction(scheme(flavor)),
        );
      }
      project.write('pubspec.yaml', 'name: app\n');
      final before = project.snapshot();

      final code = await apply();

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.snapshot(), before);
      expect(_preActionScripts(scheme('citrus')), hasLength(1));
    });

    test('reports a build configuration the user changed as a conflict, and '
        'keeps it', () async {
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
    });

    test(
      'keeps what the user edited outside of the build configurations',
      () async {
        await apply();
        project.write(
          '$_schemes/citrus.xcscheme',
          scheme('citrus')
              .replaceFirst('launchStyle = "0"', 'launchStyle = "1"')
              .replaceFirst(
                '<AnalyzeAction',
                '<!-- mine -->\n   <AnalyzeAction',
              ),
        );
        final before = project.snapshot();

        final code = await apply();

        expect(code, ExitCodes.ok, reason: project.logger.output);
        expect(project.snapshot(), before);
      },
    );
  });

  group('the scheme of a flavor that was dropped', () {
    /// The configuration without `dates`.
    String onlyCitrus() => _config().split('  dates:').first;

    Future<int> drop([List<String> extra = const []]) async {
      project.write('flavorizr.yaml', onlyCitrus());

      return apply(extra);
    }

    test('is deleted with its flavor, and the other stays', () async {
      await apply();

      final code = await drop();

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.exists('$_schemes/dates.xcscheme'), isFalse);
      expect(project.exists('$_schemes/citrus.xcscheme'), isTrue);
      expect(project.exists(_runner), isTrue);
    });

    test('leaves the lock with the one of the flavor that stays, and a run '
        'after it has nothing to do', () async {
      await apply();
      await drop();

      final record = (await LockStore(
        project.root,
        runningVersion: '3.0.0',
      ).read())!.processors['ios:schema']!;

      expect(record.files.keys, ['$_schemes/citrus.xcscheme']);
      expect(record.keys.keys, ['$_schemes/citrus.xcscheme']);

      final before = project.snapshot();

      expect(await apply(), ExitCodes.ok, reason: project.logger.output);
      expect(project.snapshot(), before);
    });

    test('is deleted whichever version of the lock recorded it', () async {
      await apply();

      expect(project.read('flavorizr.lock'), contains('schemaVersion: 2'));
      expect(project.read('flavorizr.lock'), contains('created: sha256:'));

      // The same record, as the first format wrote it.
      project.write(
        'flavorizr.lock',
        project
            .read('flavorizr.lock')
            .replaceFirst('schemaVersion: 2', 'schemaVersion: 1'),
      );

      final code = await drop();

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.exists('$_schemes/dates.xcscheme'), isFalse);
      expect(project.read('flavorizr.lock'), contains('schemaVersion: 2'));
      expect(project.read('flavorizr.lock'), isNot(contains('dates')));
    });

    test('is in the plan as a deletion before it happens, and `status` is '
        'out of sync', () async {
      await apply();
      project.write('flavorizr.yaml', onlyCitrus());
      final before = project.snapshot();

      expect(await project.run(['plan', ..._targets]), ExitCodes.ok);
      expect(project.logger.output, contains('$_schemes/dates.xcscheme'));
      expect(project.logger.output, contains('1 to delete'));
      expect(project.snapshot(), before);

      project.logger.lines.clear();

      expect(await project.run(['status', ..._targets]), isNot(ExitCodes.ok));
      expect(project.logger.output, contains('$_schemes/dates.xcscheme'));
    });

    test('is a deletion in the document of `--json`, a conflict when edited '
        'more than it owns', () async {
      await apply();
      project.write('flavorizr.yaml', onlyCitrus());

      Future<Map<String, Object?>> change({int code = 0}) async {
        project.stdout.clear();

        expect(
          await project.run(['plan', '--json', ..._targets]),
          code,
          reason: project.logger.output,
        );

        return {
          for (final change
              in ((jsonDecode(project.stdout.toString())
                          as Map<String, Object?>)['changes']
                      as List<Object?>)
                  .cast<Map<String, Object?>>())
            change['path']! as String: change,
        }['$_schemes/dates.xcscheme']!;
      }

      expect(await change(), containsPair('change', 'deleted'));
      expect(await change(), containsPair('disposition', 'apply'));

      project.write(
        '$_schemes/dates.xcscheme',
        _edited(
          scheme('dates'),
          (source) =>
              source.replaceFirst('launchStyle = "0"', 'launchStyle = "1"'),
        ),
      );

      expect(
        await change(code: ExitCodes.attention),
        containsPair('disposition', 'conflict'),
      );
    });

    test('is deleted when only what Flutter and the user may edit changed: the '
        'build configurations and the pre-action of Flutter', () async {
      await apply();
      project.write(
        '$_schemes/dates.xcscheme',
        _edited(
          withFlutterPreAction(scheme('dates')),
          (source) => source.replaceFirst(
            'buildConfiguration = "Release-dates"',
            'buildConfiguration = "Release"',
          ),
        ),
      );

      final code = await drop();

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.exists('$_schemes/dates.xcscheme'), isFalse);
    });

    test('is deleted when Xcode saved it with another layout', () async {
      await apply();
      project.write(
        '$_schemes/dates.xcscheme',
        _edited(scheme('dates'), (source) => source.replaceAll('   ', ' ')),
      );

      final code = await drop();

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.exists('$_schemes/dates.xcscheme'), isFalse);
    });

    test('is kept, and reported as a conflict, when the user edited more than '
        'its build configurations', () async {
      await apply();
      project.write(
        '$_schemes/dates.xcscheme',
        _edited(
          scheme('dates'),
          (source) =>
              source.replaceFirst('launchStyle = "0"', 'launchStyle = "1"'),
        ),
      );

      final code = await drop();

      expect(code, ExitCodes.attention, reason: project.logger.output);
      expect(project.exists('$_schemes/dates.xcscheme'), isTrue);
      expect(project.logger.output, contains('$_schemes/dates.xcscheme'));
    });

    test('has its own pre-action taken for the one of Flutter, and a script of '
        'the user that mentions it is a conflict', () async {
      await apply();

      expect(scheme('dates'), contains('ExecutionAction'));
      expect(
        SchemeEditor.foreignContent(scheme('dates')),
        isNot(contains('ExecutionAction')),
      );

      project.write(
        '$_schemes/dates.xcscheme',
        scheme('dates').replaceFirst(
          '</PreActions>',
          '''<ExecutionAction ActionType = "Xcode.IDEStandardExecutionActionsCore.ExecutionActionType.ShellScriptAction">
            <ActionContent title = "Mine" scriptText = "echo xcode_backend.sh prepare&#10;"></ActionContent>
         </ExecutionAction></PreActions>''',
        ),
      );

      final code = await drop();

      expect(code, ExitCodes.attention, reason: project.logger.output);
      expect(project.exists('$_schemes/dates.xcscheme'), isTrue);
    });

    test(
      'is deleted after all when the conflict is told to overwrite',
      () async {
        await apply();
        project.write(
          '$_schemes/dates.xcscheme',
          _edited(
            scheme('dates'),
            (source) =>
                source.replaceFirst('launchStyle = "0"', 'launchStyle = "1"'),
          ),
        );

        final code = await drop(['--on-conflict', 'overwrite']);

        expect(code, ExitCodes.ok, reason: project.logger.output);
        expect(project.exists('$_schemes/dates.xcscheme'), isFalse);
      },
    );

    test('is patched in place when its flavor comes back after the user kept '
        'it', () async {
      await apply();
      final mine = _edited(
        scheme('dates'),
        (source) =>
            source.replaceFirst('launchStyle = "0"', 'launchStyle = "1"'),
      );
      project.write('$_schemes/dates.xcscheme', mine);
      await drop();
      project.write('flavorizr.yaml', _config());

      final code = await apply();

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(scheme('dates'), mine);
    });

    test(
      'is made again when its flavor comes back, and goes with it again',
      () async {
        await apply();
        await drop();
        project.write('flavorizr.yaml', _config());

        final code = await apply();

        expect(code, ExitCodes.ok, reason: project.logger.output);
        expect(
          _configurations(scheme('dates'))['ArchiveAction'],
          'Release-dates',
        );

        await drop();

        expect(project.exists('$_schemes/dates.xcscheme'), isFalse);
      },
    );

    test('is left alone when flavorizr did not make it: the user had it '
        'already', () async {
      project.write(
        '$_schemes/dates.xcscheme',
        File(
          'test_resources/example_2x/ios/Runner.xcodeproj/xcshareddata/'
          'xcschemes/Runner.xcscheme',
        ).readAsStringSync(),
      );
      await apply();

      final code = await drop();

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.exists('$_schemes/dates.xcscheme'), isTrue);
      expect(
        project.logger.output,
        allOf(
          contains('Left in place'),
          contains('dates.xcscheme (flavorizr did not make it'),
        ),
      );
    });

    test('is deleted by a run of `ios:schema` alone', () async {
      await apply();
      project.write('flavorizr.yaml', onlyCitrus());

      final code = await project.run(['apply', '--yes', 'ios:schema']);

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.exists('$_schemes/dates.xcscheme'), isFalse);
    });

    test(
      'is not touched by a run that does not include `ios:schema`',
      () async {
        await apply();
        project.write('flavorizr.yaml', onlyCitrus());

        final code = await project.run(['apply', '--yes', 'flutter:flavors']);

        expect(code, ExitCodes.ok, reason: project.logger.output);
        expect(project.exists('$_schemes/dates.xcscheme'), isTrue);
      },
    );

    test('is deleted when the flavor only loses its iOS section', () async {
      await apply();
      project.write(
        'flavorizr.yaml',
        _config().replaceFirst(
          '    ios:\n      bundleId: "com.example.dates"\n',
          '    android:\n      applicationId: "com.example.dates"\n',
        ),
      );

      final code = await apply();

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(project.exists('$_schemes/dates.xcscheme'), isFalse);
      expect(project.exists('$_schemes/citrus.xcscheme'), isTrue);
    });
  });

  group('an existing scheme', () {
    /// What 2.x wrote: no pre-action, no build entries.
    String legacy(String flavor) =>
        File(
              'test_resources/example_2x/ios/Runner.xcodeproj/xcshareddata/'
              'xcschemes/Runner.xcscheme',
            )
            .readAsStringSync()
            .replaceAll('"Debug"', '"Debug-$flavor"')
            .replaceAll('"Release"', '"Release-$flavor"')
            .replaceAll('"Profile"', '"Profile-$flavor"');

    test('gets only its build configurations changed', () async {
      final user = File(
        'test_resources/example_2x/ios/Runner.xcodeproj/xcshareddata/xcschemes/'
        'Runner.xcscheme',
      ).readAsStringSync();
      project.write('$_schemes/citrus.xcscheme', user);

      final code = await apply();

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(scheme('citrus'), legacy('citrus'));
    });

    test('keeps the pre-actions that are there, and adds no other', () async {
      final mine =
          File(
            'test_resources/example_2x/ios/Runner.xcodeproj/xcshareddata/xcschemes/'
            'Runner.xcscheme',
          ).readAsStringSync().replaceFirst('      <BuildActionEntries>', '''
      <PreActions>
         <ExecutionAction
            ActionType = "Xcode.IDEStandardExecutionActionsCore.ExecutionActionType.ShellScriptAction">
            <ActionContent
               title = "Mine"
               scriptText = "echo &quot;a &amp; b&quot;&#10;">
            </ActionContent>
         </ExecutionAction>
      </PreActions>
      <BuildActionEntries>''');
      project.write('$_schemes/citrus.xcscheme', mine);

      final code = await apply();

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(_preActionScripts(scheme('citrus')), ['echo "a & b"\n']);
      expect(_configurations(scheme('citrus'))['LaunchAction'], 'Debug-citrus');
    });

    test('keeps the pre-action Flutter injected', () async {
      final injected = withFlutterPreAction(
        File(
          'test_resources/example_2x/ios/Runner.xcodeproj/xcshareddata/'
          'xcschemes/Runner.xcscheme',
        ).readAsStringSync(),
      );
      project.write('$_schemes/citrus.xcscheme', injected);

      final code = await apply();

      expect(code, ExitCodes.ok, reason: project.logger.output);
      expect(_preActions(scheme('citrus')), _preActions(injected));
      expect(_preActions(injected), hasLength(1));
      expect(_preActionScripts(scheme('citrus')), hasLength(1));
      expect(_configurations(scheme('citrus')), {
        'LaunchAction': 'Debug-citrus',
        'TestAction': 'Debug-citrus',
        'ProfileAction': 'Profile-citrus',
        'AnalyzeAction': 'Debug-citrus',
        'ArchiveAction': 'Release-citrus',
      });
    });
  });
}
