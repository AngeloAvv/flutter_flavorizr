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
import 'package:xml/xml.dart';

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
    /// The foreign content of [source], which has to be XML: a source that
    /// is not is its own foreign content, and a test of an edit that broke the
    /// XML would pass for what it did not test.
    String foreignOf(String source) {
      XmlDocument.parse(source);

      return SchemeEditor.foreignContent(source);
    }

    final foreign = foreignOf(_pristine);

    test('does not change with the build configurations', () {
      final edited = _pristine
          .replaceAll('"Debug"', '"Debug-dates"')
          .replaceAll('"Release"', '"Release-dates"')
          .replaceAll('"Profile"', '"Profile-dates"');

      expect(edited, isNot(_pristine));
      expect(foreignOf(edited), foreign);
    });

    test('does not change when Flutter injects its pre-action, for iOS or '
        'macOS', () {
      for (final platform in ['ios', 'macos']) {
        final injected = withFlutterPreAction(_pristine, platform: platform);

        expect(injected, isNot(_pristine));
        expect(foreignOf(injected), foreign);
      }
    });

    test('does not change with the layout Xcode saves the scheme with', () {
      final relaid = _pristine
          .replaceAll(RegExp(r'\n\s*'), '\n')
          .replaceFirst(RegExp(r'<Scheme\s'), '<Scheme ');

      expect(relaid, isNot(_pristine));
      expect(foreignOf(relaid), foreign);
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
        expect(foreignOf(edited), isNot(foreign));
      }
    });

    /// A pre-action that is [script] of the title [title], in a scheme that has
    /// none.
    String withAction(
      String script, {
      String title = SchemeEditor.prepareTitle,
      String after = '',
    }) {
      final action =
          '''<PreActions>
         <ExecutionAction ActionType = "Xcode.IDEStandardExecutionActionsCore.ExecutionActionType.ShellScriptAction">
            <ActionContent title = "$title" scriptText = "$script">$after</ActionContent>
         </ExecutionAction>
      </PreActions>''';

      return _pristine.replaceFirst(
        '<BuildActionEntries>',
        '$action\n<BuildActionEntries>',
      );
    }

    test('keeps a script of the user that only mentions the one of Flutter', () {
      for (final edited in [
        withAction('echo xcode_backend.sh prepare&#10;', title: 'Mine'),
        withAction('echo xcode_backend.sh prepare&#10;'),
        withAction(
          '/bin/sh &quot;\$FLUTTER_ROOT/packages/flutter_tools/bin/xcode_backend.sh&quot; prepare&#10;echo mine&#10;',
        ),
        withAction(
          '/bin/sh &quot;\$FLUTTER_ROOT/packages/flutter_tools/bin/xcode_backend.sh&quot; prepare&#10;',
          title: 'Mine',
        ),
        withAction(
          '/bin/sh &quot;\$FLUTTER_ROOT/packages/flutter_tools/bin/xcode_backend.sh&quot; prepare&#10;',
          after: '<!-- mine -->',
        ),
        withAction(
          '/bin/sh &quot;\$FLUTTER_ROOT/packages/flutter_tools/bin/xcode_backend.sh&quot; prepare&#10;',
          after: '<Mine/>',
        ),
      ]) {
        expect(foreignOf(edited), isNot(foreign), reason: edited);
      }
    });

    test('keeps the pre-action of Flutter outside of the build action', () {
      final injected = withFlutterPreAction(_pristine);
      final action = RegExp(
        r'<PreActions>[\s\S]*?</PreActions>',
      ).firstMatch(injected)!.group(0)!;
      final moved = _pristine.replaceFirstMapped(
        RegExp(r'<LaunchAction[^>]*>'),
        (match) => '${match.group(0)}\n$action',
      );

      // The scheme has it in the launch action, and no pre-action in the
      // build action.
      expect(
        XmlDocument.parse(
          moved,
        ).rootElement.getElement('LaunchAction')!.getElement('PreActions'),
        isNotNull,
      );
      expect(foreignOf(moved), isNot(foreign));
    });

    test('keeps a pre-action that looks like the one of Flutter when it is '
        'for another target, or has more in it', () {
      final injected = withFlutterPreAction(_pristine);

      for (final edited in [
        injected.replaceFirstMapped(
          RegExp(
            r'(<EnvironmentBuildable>[\s\S]*?BlueprintIdentifier = )"[^"]*"',
          ),
          (match) => '${match.group(1)}"0123456789ABCDEF"',
        ),
        injected.replaceFirst(
          '</EnvironmentBuildable>',
          '<Mine/></EnvironmentBuildable>',
        ),
        injected.replaceFirst(
          '<EnvironmentBuildable>',
          '<EnvironmentBuildable><!-- mine -->',
        ),
      ]) {
        expect(edited, isNot(injected));
        expect(foreignOf(edited), isNot(foreign));
      }
    });

    test('keeps a comment in a pre-actions container, with or without the '
        'action of Flutter', () {
      final bare = _pristine.replaceFirst(
        '<BuildActionEntries>',
        '<PreActions><!-- deployment note --></PreActions>\n<BuildActionEntries>',
      );
      final injected = withFlutterPreAction(bare);

      expect(foreignOf(bare), isNot(foreign));
      expect(foreignOf(injected), foreignOf(bare));
      expect(
        foreignOf(bare.replaceFirst('deployment note', 'another note')),
        isNot(foreignOf(bare)),
      );
    });

    test('does not depend on the whitespace around the pre-action of '
        'Flutter', () {
      final injected = withFlutterPreAction(_pristine);

      expect(
        foreignOf(injected.replaceFirst('<PreActions>', '<PreActions>\n\n   ')),
        foreign,
      );
    });

    test('keeps a comment outside of the root element', () {
      for (final edited in [
        _pristine.replaceFirst('<Scheme', '<!-- deployment note -->\n<Scheme'),
        '$_pristine\n<!-- deployment note -->\n',
      ]) {
        expect(foreignOf(edited), isNot(foreign));
      }

      expect(
        foreignOf(
          _pristine.replaceFirst('<Scheme', '<!--  note  -->\n<Scheme'),
        ),
        foreignOf(_pristine.replaceFirst('<Scheme', '<!-- note -->\n<Scheme')),
      );
    });

    test('does not depend on line endings, nor on the order of the '
        'attributes', () {
      expect(foreignOf(_pristine.replaceAll('\n', '\r\n')), foreign);
      expect(
        foreignOf(
          _pristine.replaceFirst(
            RegExp(r'LastUpgradeVersion = "1510"\s+version = "1.3"'),
            'version = "1.3" LastUpgradeVersion = "1510"',
          ),
        ),
        foreign,
      );
    });

    test('tells a comment from text, and does not depend on CDATA', () {
      String scheme(String child) =>
          _pristine.replaceFirst('</Scheme>', '<Mine>$child</Mine>\n</Scheme>');

      expect(foreignOf(scheme('<![CDATA[a]]>')), foreignOf(scheme('a')));
      expect(foreignOf(scheme('<!--a-->')), isNot(foreignOf(scheme('a'))));
    });

    test('is the whole text when the scheme is not XML', () {
      expect(SchemeEditor.foreignContent('<Scheme'), '<Scheme');
    });
  });
}
