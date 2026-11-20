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
  /// text that does not depend on the layout (the order of the attributes, the
  /// indentation and the line breaks).
  ///
  /// It is how a scheme flavorizr made is told from one the user edited when its
  /// flavor is dropped: the lock records it for a scheme flavorizr creates
  /// (`recordCreated`), and the scheme is deleted only while it is still the
  /// same. The three things that may change in a scheme flavorizr made, without
  /// it ceasing to be its own, are exactly what is left out: the build
  /// configurations it owns, the pre-action Flutter injects when Swift Package
  /// Manager is turned on later, and the layout Xcode saves it with. Everything
  /// else (the arguments, the environment, the targets, a pre-action or a
  /// comment of the user) is the user's, and a change of it makes the scheme
  /// theirs.
  ///
  /// A [source] that is not XML is its own foreign content, so that whatever
  /// happens to it is seen.
  static String foreignContent(String source) {
    final XmlDocument document;

    try {
      document = XmlDocument.parse(source);
    } on XmlException {
      return source;
    }

    final scheme = document.rootElement.copy();

    for (final action in ownedActions) {
      scheme.getElement(action)?.removeAttribute('buildConfiguration');
    }

    for (final container in scheme.findAllElements('PreActions').toList()) {
      for (final action in container.childElements.toList()) {
        if (_isPrepareAction(action)) action.remove();
      }

      if (container.childElements.isEmpty) container.remove();
    }

    final buffer = StringBuffer();

    _write(scheme, buffer);

    return buffer.toString();
  }

  /// Whether [action], an `ExecutionAction`, is the pre-action Flutter adds:
  /// the one that runs `xcode_backend.sh` or `macos_assemble.sh` with `prepare`,
  /// whatever it is called.
  static bool _isPrepareAction(XmlElement action) {
    for (final content in action.findAllElements('ActionContent')) {
      final script = content.getAttribute('scriptText') ?? '';

      if (content.getAttribute('title') == prepareTitle ||
          (RegExp(r'(xcode_backend|macos_assemble)\.sh').hasMatch(script) &&
              RegExp(r'\bprepare\b').hasMatch(script))) {
        return true;
      }
    }

    return false;
  }

  /// [element] as one line per node, indented by depth, with its attributes by
  /// name: the layout of the source is not in it.
  static void _write(XmlElement element, StringBuffer buffer, [int depth = 0]) {
    final attributes = [
      for (final attribute in element.attributes)
        '${attribute.name.qualified}=${jsonEncode(attribute.value)}',
    ]..sort();

    buffer.writeln(
      '${' ' * depth}<${element.name.qualified} '
      '${attributes.join(' ')}>',
    );

    for (final child in element.children) {
      switch (child) {
        case XmlElement():
          _write(child, buffer, depth + 1);
        case XmlText() || XmlCDATA() || XmlComment():
          final text = child.value?.trim() ?? '';

          if (text.isNotEmpty) {
            buffer.writeln('${' ' * (depth + 1)}${jsonEncode(text)}');
          }
        default:
          break;
      }
    }
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
