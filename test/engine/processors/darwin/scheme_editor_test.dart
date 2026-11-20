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
    /// The foreign content of [source], which has to be XML: a source that is
    /// not is its own foreign content, and a test of an edit that broke the XML
    /// would pass for what it did not test.
    String foreignOf(String source) {
      XmlDocument.parse(source);

      return SchemeEditor.foreignContent(source);
    }

    final foreign = foreignOf(_pristine);

    /// [from] replaced by [to], which has to be there: an edit that finds
    /// nothing to edit would test nothing.
    String Function(String) swap(String from, String to) => (source) {
      expect(source, contains(from));

      return source.replaceFirst(from, to);
    };

    /// The first match of [pattern] replaced by [to].
    String Function(String) swapMatch(RegExp pattern, String to) => (source) {
      expect(pattern.hasMatch(source), isTrue);

      return source.replaceFirst(pattern, to);
    };

    /// [source] as Flutter leaves it after a build, then edited by [edit].
    String Function(String) afterFlutter(String Function(String) edit) =>
        (source) => edit(withFlutterPreAction(source));

    const shell =
        'Xcode.IDEStandardExecutionActionsCore.ExecutionActionType.'
        'ShellScriptAction';
    const prepare =
        r'/bin/sh &quot;$FLUTTER_ROOT/packages/flutter_tools/bin/'
        r'xcode_backend.sh&quot; prepare&#10;';

    /// A pre-action of the build action, in a container of its own.
    String Function(String) preAction({
      String title = SchemeEditor.prepareTitle,
      String script = prepare,
      String action = '',
      String content = '',
      String inside = '',
    }) => swap(
      '<BuildActionEntries>',
      '<PreActions><ExecutionAction ActionType = "$shell"$action>'
          '<ActionContent title = "$title" scriptText = "$script"$content>'
          '$inside</ActionContent></ExecutionAction></PreActions>'
          '<BuildActionEntries>',
    );

    final changes = <String, String Function(String)>{
      // Elements and their attributes.
      'an attribute of the root changed': swap(
        'version = "1.3"',
        'version = "1.4"',
      ),
      'an attribute added to the root': swap('<Scheme', '<Scheme mine = "1"'),
      'an attribute removed from the root': swap('version = "1.3">', '>'),
      'an attribute of an element changed': swap(
        'launchStyle = "0"',
        'launchStyle = "1"',
      ),
      'an attribute removed from an element': swap('launchStyle = "0"', ''),
      'an attribute added to the build action': swap(
        '<BuildAction',
        '<BuildAction mine = "1"',
      ),
      'an attribute added to an owned action': swap(
        '<ArchiveAction',
        '<ArchiveAction mine = "1"',
      ),
      'an attribute of an owned action changed': swap(
        'revealArchiveInOrganizer = "YES"',
        'revealArchiveInOrganizer = "NO"',
      ),
      'an attribute removed from an owned action': swap(
        'revealArchiveInOrganizer = "YES"',
        '',
      ),
      'a build configuration on an element that does not own one': swap(
        '<MacroExpansion>',
        '<MacroExpansion buildConfiguration = "Debug">',
      ),
      'an element added': swap('</Scheme>', '<Mine/></Scheme>'),
      'an element added to an owned action': swap(
        '</ArchiveAction>',
        '<Mine/></ArchiveAction>',
      ),
      'an element removed': swapMatch(
        RegExp(r'<ArchiveAction[\s\S]*?</ArchiveAction>'),
        '',
      ),
      'an element renamed': (source) {
        expect(source, contains('Testables'));

        return source.replaceAll('Testables', 'TestablesX');
      },
      // Text.
      'a text added': swap('</Scheme>', '<Mine>a</Mine></Scheme>'),
      'a text added to an owned action': swap(
        '</AnalyzeAction>',
        'text</AnalyzeAction>',
      ),
      'a CDATA section added': swap(
        '</Scheme>',
        '<Mine><![CDATA[a]]></Mine></Scheme>',
      ),
      // Comments.
      'a comment before the root': swap('<Scheme', '<!-- mine -->\n<Scheme'),
      'a comment after the root': (source) => '$source\n<!-- mine -->\n',
      'a comment in an element': swap(
        '<MacroExpansion>',
        '<MacroExpansion><!-- mine -->',
      ),
      'a comment in an owned action': swap(
        '</AnalyzeAction>',
        '<!-- mine --></AnalyzeAction>',
      ),
      // Processing instructions.
      'a processing instruction before the root': swap(
        '<Scheme',
        '<?mine a?>\n<Scheme',
      ),
      'a processing instruction after the root': (source) =>
          '$source\n<?mine a?>\n',
      'a processing instruction in an element': swap(
        '</Scheme>',
        '<?mine a?></Scheme>',
      ),
      // The document type and the declaration.
      'a document type': swap('<Scheme', '<!DOCTYPE Scheme>\n<Scheme'),
      'the encoding of the declaration': swap(
        'encoding="UTF-8"',
        'encoding="UTF-16"',
      ),
      'a standalone declaration': swap(
        'encoding="UTF-8"?>',
        'encoding="UTF-8" standalone="yes"?>',
      ),
      // What may be in the container of the pre-actions of the build action,
      // and is not Flutter's.
      'an empty pre-actions container': swap(
        '<BuildActionEntries>',
        '<PreActions/><BuildActionEntries>',
      ),
      'a pre-actions container with an attribute': swap(
        '<BuildActionEntries>',
        '<PreActions keep = "true"/><BuildActionEntries>',
      ),
      'a pre-actions container with an attribute and the action of Flutter':
          afterFlutter(swap('<PreActions>', '<PreActions keep = "true">')),
      'a comment in a pre-actions container': swap(
        '<BuildActionEntries>',
        '<PreActions><!-- mine --></PreActions><BuildActionEntries>',
      ),
      'a comment in a pre-actions container with the action of Flutter':
          afterFlutter(swap('<PreActions>', '<PreActions><!-- mine -->')),
      'a text in a pre-actions container with the action of Flutter':
          afterFlutter(swap('<PreActions>', '<PreActions>mine')),
      'a processing instruction in a pre-actions container': afterFlutter(
        swap('<PreActions>', '<PreActions><?mine a?>'),
      ),
      'an action of the user in the pre-actions of the build action': preAction(
        title: 'Mine',
        script: 'echo mine&#10;',
      ),
      'an action of the user next to the action of Flutter': afterFlutter(
        swap(
          '</PreActions>',
          '<ExecutionAction ActionType = "$shell"><ActionContent title = "Mine" '
              'scriptText = "echo mine&#10;"></ActionContent></ExecutionAction>'
              '</PreActions>',
        ),
      ),
      // What looks like the pre-action of Flutter and is not.
      'a script that only mentions the one of Flutter': preAction(
        script: 'echo xcode_backend.sh prepare&#10;',
      ),
      'the title of the user': preAction(title: 'Mine'),
      'a command added to the one of Flutter': preAction(
        script: '${prepare}echo mine&#10;',
      ),
      'an attribute on the action': preAction(action: ' mine = "1"'),
      'an attribute on the content': preAction(content: ' mine = "1"'),
      'a comment in the content': preAction(inside: '<!-- mine -->'),
      'an element in the content': preAction(inside: '<Mine/>'),
      'a text in the content': preAction(inside: 'mine'),
      'a pre-action of Flutter in the launch action': (source) {
        final action = RegExp(
          r'<PreActions>[\s\S]*?</PreActions>',
        ).firstMatch(withFlutterPreAction(source))!.group(0)!;
        final launch = RegExp(r'<LaunchAction[^>]*>');

        expect(launch.hasMatch(source), isTrue);

        return source.replaceFirstMapped(
          launch,
          (match) => '${match.group(0)}$action',
        );
      },
      'a pre-action of Flutter for another target': (source) {
        final target = RegExp(
          r'(<EnvironmentBuildable>[\s\S]*?BlueprintIdentifier = )"[^"]*"',
        );
        final injected = withFlutterPreAction(source);

        expect(target.hasMatch(injected), isTrue);

        return injected.replaceFirstMapped(
          target,
          (match) => '${match.group(1)}"0123456789ABCDEF"',
        );
      },
    };

    for (final MapEntry(key: name, value: edit) in changes.entries) {
      test('changes with $name', () {
        // The edits that need the scheme to be one of Flutter's are made of it.
        final edited = edit(_pristine);

        expect(edited, isNot(_pristine));
        expect(foreignOf(edited), isNot(foreign));
      });
    }

    final unchanged = <String, String Function(String)>{
      // 1. What flavorizr owns.
      'the build configurations': (source) => source
          .replaceAll('"Debug"', '"Debug-dates"')
          .replaceAll('"Release"', '"Release-dates"')
          .replaceAll('"Profile"', '"Profile-dates"'),
      'a build configuration removed': swap(
        'buildConfiguration = "Release"',
        '',
      ),
      // 2. What Flutter adds.
      'the pre-action of Flutter for iOS': (source) =>
          withFlutterPreAction(source),
      'the pre-action of Flutter for macOS': (source) =>
          withFlutterPreAction(source, platform: 'macos'),
      'the pre-action of Flutter with other whitespace': afterFlutter(
        swap('<PreActions>', '<PreActions>\n\n   '),
      ),
      // 3. Formatting.
      'the line endings': (source) => source.replaceAll('\n', '\r\n'),
      'the order of the attributes': swapMatch(
        RegExp(r'LastUpgradeVersion = "1510"\s+version = "1.3"'),
        'version = "1.3" LastUpgradeVersion = "1510"',
      ),
      'the quotes of the attributes': (source) => source.replaceAll('"', "'"),
      'the escaping of an attribute': swap(
        'launchStyle = "0"',
        'launchStyle = "&#48;"',
      ),
      'the whitespace between the nodes': (source) =>
          source.replaceAll(RegExp(r'\n\s*'), '\n'),
      'the indentation': (source) => source.replaceAll('   ', '  '),
    };

    for (final MapEntry(key: name, value: edit) in unchanged.entries) {
      test('does not change with $name', () {
        final edited = edit(_pristine);

        expect(edited, isNot(_pristine));
        expect(foreignOf(edited), foreign);
      });
    }

    String withText(String child) =>
        swap('</Scheme>', '<Mine>$child</Mine></Scheme>')(_pristine);

    test('does not change with how a text is written', () {
      expect(foreignOf(withText('<![CDATA[a]]>')), foreignOf(withText('a')));
      expect(foreignOf(withText('\n  a  \n')), foreignOf(withText('a')));
      expect(foreignOf(withText('a<![CDATA[b]]>')), foreignOf(withText('ab')));
    });

    test('changes with what a text, a comment or an instruction says', () {
      final variants = [
        withText('a'),
        withText('b'),
        withText('a  b'),
        withText('<!--a-->'),
        withText('<!-- a -->'),
        withText('<!--b-->'),
        withText('<?a b?>'),
        withText('<?a c?>'),
        withText('<?c b?>'),
      ];

      expect({
        for (final source in variants) foreignOf(source),
      }, hasLength(variants.length));
    });

    test('does not change with the pre-action of Flutter in a container of the '
        'user', () {
      final bare = swap(
        '<BuildActionEntries>',
        '<PreActions><!-- mine --></PreActions><BuildActionEntries>',
      )(_pristine);

      expect(foreignOf(withFlutterPreAction(bare)), foreignOf(bare));
    });

    test('is the whole text when the scheme is not XML', () {
      expect(SchemeEditor.foreignContent('<Scheme'), '<Scheme');
    });
  });
}
