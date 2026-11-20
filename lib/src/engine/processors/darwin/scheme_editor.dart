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

import 'package:dart_xcodeproj/dart_xcodeproj.dart';
import 'package:xml/xml.dart';

/// The script Flutter runs before the build of a scheme, by platform, when
/// Swift Package Manager is enabled.
///
/// Flutter adds it to the scheme of the flavor on the first build
/// (`_migrateScheme` of `swift_package_manager_integration_migration.dart` in
/// `flutter_tools`), and it leaves a scheme alone that mentions the script
/// already. A scheme that is made with it is never touched by Flutter, and the
/// iOS and macOS schemes differ in nothing else.
enum PrepareScript {
  /// `xcode_backend.sh prepare`.
  ios(
    r'/bin/sh "$FLUTTER_ROOT/packages/flutter_tools/bin/xcode_backend.sh" prepare',
  ),

  /// `macos_assemble.sh prepare`.
  macos(
    r'"$FLUTTER_ROOT"/packages/flutter_tools/bin/macos_assemble.sh prepare',
  );

  /// The command the pre-action runs, one line.
  final String command;

  const PrepareScript(this.command);

  /// The text of the `scriptText` attribute, as Flutter writes it.
  String get scriptText => '$command\n';
}

/// What flavorizr owns of a scheme (`*.xcscheme`), and the edits it makes.
///
/// A scheme is a **patched** artifact: the file belongs to the user, to Xcode
/// and to Flutter, which adds its pre-action to it. Flavorizr owns two things
/// only:
///
/// * its existence, a scheme per flavor, made with the pre-action of Flutter
///   when Swift Package Manager is enabled;
/// * the `buildConfiguration` attribute of the five actions that run a build:
///   Launch, Test, Profile, Analyze and Archive ([ownedActions]).
///
/// The pre-actions, the build entries, the arguments, the environment and every
/// other attribute are never read for their value and never removed.
abstract final class SchemeEditor {
  /// The actions of a scheme whose `buildConfiguration` flavorizr owns, in the
  /// order the lock hashes them.
  static const ownedActions = [
    'LaunchAction',
    'TestAction',
    'ProfileAction',
    'AnalyzeAction',
    'ArchiveAction',
  ];

  /// The title of the pre-action of Flutter.
  static const prepareTitle = 'Run Prepare Flutter Framework Script';

  static const _shellScriptAction =
      'Xcode.IDEStandardExecutionActionsCore.ExecutionActionType.'
      'ShellScriptAction';

  /// The part of the scheme in [source] that flavorizr owns: the build
  /// configuration of each of the [ownedActions] the scheme has, one per line.
  ///
  /// It is what the lock hashes, so that an edit of anything else, by Xcode, by
  /// Flutter or by the user, is never drift. A [source] that is not XML is its
  /// own owned content, so that whatever happens to it is seen.
  static String ownedContent(String source) {
    final XmlDocument document;

    try {
      document = XmlDocument.parse(source);
    } on XmlException {
      return source;
    }

    final scheme = document.rootElement;

    return [
      for (final action in ownedActions)
        if (scheme.getElement(action)?.getAttribute('buildConfiguration')
            case final configuration?)
          '$action buildConfiguration = $configuration',
    ].join('\n');
  }

  /// What the scheme in [source] holds that flavorizr does not own, nor Flutter
  /// adds on its own: the scheme as it is **without** the build configuration of
  /// the [ownedActions] and without the pre-action of Flutter, as a canonical
  /// text that does not depend on the layout.
  ///
  /// It is how a scheme flavorizr made is told from one the user edited when its
  /// flavor is dropped: the lock records it for a scheme flavorizr creates
  /// (`recordCreated`), and the scheme is deleted only while it is still the
  /// same. The three things that may change in a scheme flavorizr made, without
  /// it ceasing to be its own, are exactly what is left out: the build
  /// configurations it owns, the pre-action Flutter injects when Swift Package
  /// Manager is turned on later ([_isPrepareAction]: only that one, as Flutter
  /// writes it), and the layout Xcode saves it with. Everything else is the
  /// user's, and a change of it makes the scheme theirs: the arguments, the
  /// environment, the targets, a script, and **any comment**, inside the scheme
  /// or around it.
  ///
  /// What the layout is: the line endings, the order, the quotes and the
  /// escaping of the attributes, the whitespace between the nodes and around a
  /// text or a comment, and whether a text is written as a CDATA section. The
  /// XML declaration and a document type are not content.
  ///
  /// A [source] that is not XML is its own foreign content, so that whatever
  /// happens to it is seen.
  static String foreignContent(String source) {
    final XmlDocument document;

    try {
      // A parser may leave a carriage return in an attribute, where it is not
      // layout to the one that wrote it.
      document = XmlDocument.parse(
        source.replaceAll('\r\n', '\n').replaceAll('\r', '\n'),
      );
    } on XmlException {
      return source;
    }

    final scheme = document.rootElement;

    for (final action in ownedActions) {
      scheme.getElement(action)?.removeAttribute('buildConfiguration');
    }

    // Flutter adds its pre-action to the build action, and nowhere else.
    final preActions = scheme
        .getElement('BuildAction')
        ?.getElement('PreActions');

    if (preActions != null) {
      for (final action in preActions.childElements.toList()) {
        if (_isPrepareAction(action)) action.remove();
      }

      // What was left of the container is the user's, comments included: it
      // goes only when nothing is.
      if (!preActions.children.any(_hasContent)) preActions.remove();
    }

    final buffer = StringBuffer();

    for (final node in document.children) {
      switch (node) {
        case XmlElement():
          _write(node, buffer);
        case XmlComment():
          buffer.writeln('#comment ${jsonEncode(node.value.trim())}');
        default:
          // The declaration, a document type and the whitespace around.
          break;
      }
    }

    return buffer.toString();
  }

  /// Whether [node] is something that is there: anything but whitespace.
  static bool _hasContent(XmlNode node) => switch (node) {
    XmlText() => node.value.trim().isNotEmpty,
    _ => true,
  };

  /// Whether [action] is the pre-action Flutter adds, as Flutter writes it: a
  /// shell script action of the title [prepareTitle] that runs the script of
  /// [PrepareScript] for iOS or macOS, and nothing else. A script that only
  /// mentions it, one that runs it and something more, and a comment or an
  /// element nobody expects in it make it the user's.
  static bool _isPrepareAction(XmlElement action) {
    if (action.name.local != 'ExecutionAction' ||
        action.attributes.length != 1 ||
        action.getAttribute('ActionType') != _shellScriptAction ||
        action.descendants.any(
          (node) => node is XmlComment || node is XmlCDATA,
        ) ||
        action.descendants.whereType<XmlText>().any(_hasContent)) {
      return false;
    }

    final contents = action.childElements.toList();

    if (contents.length != 1 || contents.single.name.local != 'ActionContent') {
      return false;
    }

    final content = contents.single;

    return {
          for (final attribute in content.attributes) attribute.name.qualified,
        }.difference({'title', 'scriptText'}).isEmpty &&
        content.getAttribute('title') == prepareTitle &&
        PrepareScript.values.any(
          (script) => content.getAttribute('scriptText') == script.scriptText,
        ) &&
        content.childElements.every(
          (child) => child.name.local == 'EnvironmentBuildable',
        );
  }

  /// [element] as one line per node, indented by depth, with its attributes by
  /// name: the layout of the source is not in it.
  static void _write(XmlElement element, StringBuffer buffer, [int depth = 0]) {
    final indent = ' ' * depth;
    final attributes = [
      for (final attribute in element.attributes)
        '${attribute.name.qualified}=${jsonEncode(attribute.value)}',
    ]..sort();

    buffer.writeln(
      '$indent<${[element.name.qualified, ...attributes].join(' ')}>',
    );

    // A text and a CDATA section are one: what is written between two nodes
    // is a single string, however it is split.
    final text = StringBuffer();

    void flush() {
      final value = text.toString().trim();

      if (value.isNotEmpty) {
        buffer.writeln('$indent #text ${jsonEncode(value)}');
      }

      text.clear();
    }

    for (final child in element.children) {
      switch (child) {
        case XmlText() || XmlCDATA():
          text.write(child.value);
        case XmlElement():
          flush();
          _write(child, buffer, depth + 1);
        case XmlComment():
          flush();
          buffer.writeln('$indent #comment ${jsonEncode(child.value.trim())}');
        default:
          break;
      }
    }

    flush();
  }

  /// The build configuration each action of the scheme of [flavor] runs with.
  static Map<String, String> buildConfigurations(String flavor) => {
    'LaunchAction': 'Debug-$flavor',
    'TestAction': 'Debug-$flavor',
    'ProfileAction': 'Profile-$flavor',
    'AnalyzeAction': 'Debug-$flavor',
    'ArchiveAction': 'Release-$flavor',
  };

  /// Points the actions of [scheme] to the build configurations of [flavor],
  /// and returns whether it changed any.
  ///
  /// An action the scheme does not have is not added: it is the user's choice.
  static bool setBuildConfigurations(XCScheme scheme, String flavor) {
    final elements = {
      'LaunchAction': scheme.launchActionElement,
      'TestAction': scheme.testActionElement,
      'ProfileAction': scheme.profileActionElement,
      'AnalyzeAction': scheme.analyzeActionElement,
      'ArchiveAction': scheme.archiveActionElement,
    };
    var changed = false;

    for (final MapEntry(key: action, value: configuration)
        in buildConfigurations(flavor).entries) {
      final element = elements[action];

      if (element == null ||
          element.getAttribute('buildConfiguration') == configuration) {
        continue;
      }

      element.setAttribute('buildConfiguration', configuration);
      changed = true;
    }

    return changed;
  }

  /// Adds the pre-action of Flutter, which runs [script] for the target of
  /// [reference], to the build action of [scheme], in front of its entries, as
  /// Xcode and Flutter write it.
  ///
  /// The pre-actions that the scheme has are kept: the new one comes first, as
  /// Flutter puts it.
  static void addPrepareAction(
    XCScheme scheme,
    PrepareScript script,
    BuildableReference reference,
  ) {
    final content = ShellScriptActionContent()
      ..title = prepareTitle
      ..scriptText = script.scriptText
      ..buildableReference = reference;
    final action = ExecutionAction()
      ..actionType = _shellScriptAction
      ..setActionContent(content);
    final build = scheme.buildAction.xmlElement;
    var container = build.getElement('PreActions');

    if (container == null) {
      container = XmlElement(XmlName.qualified('PreActions'));
      build.children.insert(0, container);
    }

    container.children.insert(0, action.xmlElement.copy());
  }
}
