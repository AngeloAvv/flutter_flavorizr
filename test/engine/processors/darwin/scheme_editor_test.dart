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

import 'package:flutter_flavorizr/src/engine/processors/darwin/scheme_editor.dart';
import 'package:test/test.dart';

import 'flutter_scheme.dart';

final String _pristine = File(
  'test_resources/example_2x/ios/Runner.xcodeproj/xcshareddata/xcschemes/'
  'Runner.xcscheme',
).readAsStringSync();

void main() {
  group('SchemeEditor.ownedContent', () {
    test('is the build configuration of the five actions', () {
      expect(
        SchemeEditor.ownedContent(_pristine),
        [
          'LaunchAction buildConfiguration = Debug',
          'TestAction buildConfiguration = Debug',
          'ProfileAction buildConfiguration = Profile',
          'AnalyzeAction buildConfiguration = Debug',
          'ArchiveAction buildConfiguration = Release',
        ].join('\n'),
      );
    });

    test('does not change when Flutter injects its pre-action', () {
      final injected = withFlutterPreAction(_pristine);

      expect(injected, isNot(_pristine));
      expect(
        SchemeEditor.ownedContent(injected),
        SchemeEditor.ownedContent(_pristine),
      );
    });

    test('does not change with what flavorizr does not own', () {
      final edited = _pristine
          .replaceFirst(
            'LastUpgradeVersion = "1510"',
            'LastUpgradeVersion = "9"',
          )
          .replaceFirst('launchStyle = "0"', 'launchStyle = "1"')
          .replaceFirst('<AnalyzeAction', '<!-- mine -->\n   <AnalyzeAction');

      expect(edited, isNot(_pristine));
      expect(
        SchemeEditor.ownedContent(edited),
        SchemeEditor.ownedContent(_pristine),
      );
    });

    test('changes with the build configuration of an action', () {
      final edited = _pristine.replaceFirst(
        'buildConfiguration = "Release"',
        'buildConfiguration = "Release-dev"',
      );

      expect(
        SchemeEditor.ownedContent(edited),
        contains('ArchiveAction buildConfiguration = Release-dev'),
      );
      expect(
        SchemeEditor.ownedContent(edited),
        isNot(SchemeEditor.ownedContent(_pristine)),
      );
    });

    test('leaves an action the scheme does not have out', () {
      final withoutArchive = _pristine.replaceFirst(
        RegExp(r'   <ArchiveAction[\s\S]*?</ArchiveAction>\n'),
        '',
      );

      expect(withoutArchive, isNot(contains('ArchiveAction')));
      expect(
        SchemeEditor.ownedContent(withoutArchive),
        isNot(contains('ArchiveAction')),
      );
    });

    test('is the whole text when the scheme is not XML', () {
      expect(SchemeEditor.ownedContent('<Scheme'), '<Scheme');
    });
  });

  group('SchemeEditor.foreignContent', () {
    final foreign = SchemeEditor.foreignContent(_pristine);

    test('does not change with the build configurations', () {
      final edited = _pristine
          .replaceAll('"Debug"', '"Debug-dates"')
          .replaceAll('"Release"', '"Release-dates"')
          .replaceAll('"Profile"', '"Profile-dates"');

      expect(edited, isNot(_pristine));
      expect(SchemeEditor.foreignContent(edited), foreign);
    });

    test('does not change when Flutter injects its pre-action, for iOS or '
        'macOS', () {
      for (final platform in ['ios', 'macos']) {
        final injected = withFlutterPreAction(_pristine, platform: platform);

        expect(injected, isNot(_pristine));
        expect(SchemeEditor.foreignContent(injected), foreign);
      }
    });

    test('does not change with the layout Xcode saves the scheme with', () {
      final relaid = _pristine
          .replaceAll(RegExp(r'\n\s*'), '\n')
          .replaceFirst(RegExp(r'<Scheme\s'), '<Scheme ');

      expect(relaid, isNot(_pristine));
      expect(SchemeEditor.foreignContent(relaid), foreign);
    });

    test('changes with what the user edits', () {
      for (final edited in [
        _pristine.replaceFirst('launchStyle = "0"', 'launchStyle = "1"'),
        _pristine.replaceFirst(
          '<AnalyzeAction',
          '<!-- mine -->\n<AnalyzeAction',
        ),
        _pristine.replaceFirst('</Scheme>', '<Mine/>\n</Scheme>'),
        _pristine.replaceFirst('<BuildActionEntries>', '''<PreActions>
         <ExecutionAction ActionType = "Xcode.IDEStandardExecutionActionsCore.ExecutionActionType.ShellScriptAction">
            <ActionContent title = "Mine" scriptText = "echo prepare&#10;"></ActionContent>
         </ExecutionAction>
      </PreActions>
      <BuildActionEntries>'''),
      ]) {
        expect(edited, isNot(_pristine));
        expect(SchemeEditor.foreignContent(edited), isNot(foreign));
      }
    });

    test('is the whole text when the scheme is not XML', () {
      expect(SchemeEditor.foreignContent('<Scheme'), '<Scheme');
    });
  });
}
