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

import 'package:collection/collection.dart';
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

  /// What the scheme in [source] holds that is the user's: a canonical text of
  /// the **whole** document, with three exclusions and nothing else.
  ///
  /// It is how a scheme flavorizr made is told from one the user edited when its
  /// flavor is dropped: the lock records it for a scheme flavorizr creates
  /// (`recordCreated`), and the scheme is deleted only while it is still the
  /// same. So a node of any type, at any place, that is not one of the
  /// exclusions changes it, and nothing has to be listed for that: elements and
  /// all of their attributes, text, CDATA sections, comments, processing
  /// instructions, the document type and the declaration (a node nobody
  /// expected is written as it is, too).
  ///
  /// The exclusions are what may change in a scheme flavorizr made without it
  /// ceasing to be its own:
  ///
  /// 1. **What flavorizr owns**: the `buildConfiguration` attribute of the
  ///    [ownedActions] of the scheme, whatever its value.
  /// 2. **What Flutter adds**: its pre-action, as it writes it
  ///    ([_isPrepareAction]), and the `PreActions` container of the build action
  ///    when that was all it held (no attribute, no other node but whitespace).
  /// 3. **Formatting**: the line endings; the order, the quoting and the escaping
  ///    of the attributes; the whitespace between the nodes and around a text;
  ///    and whether a text is written as a CDATA section.
  ///
  /// A [source] that is not XML is its own foreign content, so that whatever
  /// happens to it is seen.
  static String foreignContent(String source) {
    final XmlDocument document;

    try {
      document = XmlDocument.parse(
        source.replaceAll('\r\n', '\n').replaceAll('\r', '\n'),
      );
    } on XmlException {
      return source;
    }

    final buffer = StringBuffer();

    _writeChildren(document, buffer, _Context(document.rootElement), 0);

    return buffer.toString();
  }

  /// The children of [parent], one line per node, indented by [depth].
  static void _writeChildren(
    XmlNode parent,
    StringBuffer buffer,
    _Context context,
    int depth,
  ) {
    final indent = ' ' * depth;
    // A text and a CDATA section are one: what is written between two nodes is
    // a single string, however it is split.
    final text = StringBuffer();

    void flush() {
      final value = text.toString().trim();

      if (value.isNotEmpty) buffer.writeln('$indent#text ${jsonEncode(value)}');

      text.clear();
    }

    for (final node in parent.children) {
      if (node is XmlText) {
        text.write(node.value);

        continue;
      }

      if (node is XmlCDATA) {
        text.write(node.value);

        continue;
      }

      flush();

      switch (node) {
        case XmlElement() when context.isFlutterOnly(node):
          // Exclusion 2: what Flutter added, and nothing else.
          break;
        case XmlElement():
          _writeElement(node, buffer, context, depth);
        case XmlComment():
          buffer.writeln('$indent#comment ${jsonEncode(node.value)}');
        case XmlProcessing():
          buffer.writeln(
            '$indent#processing ${jsonEncode(node.target)} '
            '${jsonEncode(node.value)}',
          );
        case XmlDeclaration():
          buffer.writeln('$indent#declaration ${_attributes(node)}');
        case XmlDoctype():
          buffer.writeln('$indent#doctype ${jsonEncode(node.toXmlString())}');
        default:
          buffer.writeln('$indent#node ${jsonEncode(node.toXmlString())}');
      }
    }

    flush();
  }

  static void _writeElement(
    XmlElement element,
    StringBuffer buffer,
    _Context context,
    int depth,
  ) {
    final attributes = _attributes(
      element,
      // Exclusion 1: what flavorizr owns.
      skip: context.ownsBuildConfiguration(element)
          ? 'buildConfiguration'
          : null,
    );

    buffer.writeln(
      '${' ' * depth}<${element.name.qualified}'
      '${attributes.isEmpty ? '' : ' $attributes'}>',
    );

    _writeChildren(element, buffer, context, depth + 1);
  }

  /// The attributes of [node] by name, as `name="value"`, without [skip]:
  /// their order in the source is not in it.
  static String _attributes(XmlHasAttributes node, {String? skip}) => ([
    for (final attribute in node.attributes)
      if (attribute.name.qualified != skip)
        '${attribute.name.qualified}=${jsonEncode(attribute.value)}',
  ]..sort()).join(' ');

  /// Whether [node] has anything but whitespace in it.
  static bool _hasContent(XmlNode node) => switch (node) {
    XmlText() => node.value.trim().isNotEmpty,
    _ => true,
  };

  /// Whether [action] is the pre-action Flutter adds, as Flutter writes it: a
  /// shell script action of the title [prepareTitle] that runs the script of
  /// [PrepareScript] for iOS or macOS, for one of the [targets] the scheme builds
  /// (the attributes of their `BuildableReference`), and nothing else. A script
  /// that only mentions it, one that runs it and something more, one for another
  /// target, and an attribute, a comment or an element nobody expects in it make
  /// it the user's.
  static bool _isPrepareAction(
    XmlElement action,
    List<Map<String, String>> targets,
  ) {
    if (action.name.local != 'ExecutionAction' ||
        action.attributes.length != 1 ||
        action.getAttribute('ActionType') != _shellScriptAction ||
        action.children.any(
          (node) => node is! XmlElement && _hasContent(node),
        )) {
      return false;
    }

    final contents = action.childElements.toList();

    if (contents.length != 1 || contents.single.name.local != 'ActionContent') {
      return false;
    }

    final content = contents.single;

    return content.children.every(
          (node) => node is XmlElement || !_hasContent(node),
        ) &&
        {
          for (final attribute in content.attributes) attribute.name.qualified,
        }.difference({'title', 'scriptText'}).isEmpty &&
        content.getAttribute('title') == prepareTitle &&
        PrepareScript.values.any(
          (script) => content.getAttribute('scriptText') == script.scriptText,
        ) &&
        _refersToATarget(content, targets);
  }

  /// Whether the `ActionContent` is made of an `EnvironmentBuildable` that
  /// holds a single `BuildableReference`, which is one of the [targets], and
  /// nothing else.
  static bool _refersToATarget(
    XmlElement content,
    List<Map<String, String>> targets,
  ) {
    final buildables = content.childElements.toList();

    if (buildables.length != 1 ||
        buildables.single.name.local != 'EnvironmentBuildable' ||
        buildables.single.attributes.isNotEmpty ||
        buildables.single.children.any(
          (node) => node is! XmlElement && _hasContent(node),
        )) {
      return false;
    }

    final references = buildables.single.childElements.toList();

    if (references.length != 1 ||
        references.single.name.local != 'BuildableReference' ||
        references.single.children.any(_hasContent)) {
      return false;
    }

    final reference = _attributesOf(references.single);

    return targets.any(
      (target) => const MapEquality<String, String>().equals(target, reference),
    );
  }

  static Map<String, String> _attributesOf(XmlElement element) => {
    for (final attribute in element.attributes)
      attribute.name.qualified: attribute.value,
  };

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

/// What [SchemeEditor.foreignContent] needs to know of the scheme it reads, to
/// apply its exclusions.
final class _Context {
  final XmlElement root;

  /// What the build action builds: the attributes of its `BuildableReference`s.
  final List<Map<String, String>> targets;

  _Context(this.root)
    : targets = [
        for (final reference
            in root
                    .getElement('BuildAction')
                    ?.findAllElements('BuildActionEntry')
                    .expand(
                      (entry) => entry.findElements('BuildableReference'),
                    ) ??
                const <XmlElement>[])
          SchemeEditor._attributesOf(reference),
      ];

  /// Whether the `buildConfiguration` of [element] is flavorizr's: [element] is
  /// the action of the scheme that is one of the owned ones.
  bool ownsBuildConfiguration(XmlElement element) =>
      identical(element.parent, root) &&
      SchemeEditor.ownedActions.contains(element.name.local) &&
      identical(root.getElement(element.name.local), element);

  /// Whether [element] is only what Flutter adds: its pre-action in the
  /// `PreActions` of the build action, or that container when it holds nothing
  /// else (no attribute, and no node but its pre-action and whitespace).
  bool isFlutterOnly(XmlElement element) {
    final parent = element.parent;

    if (parent is! XmlElement || !_isBuildPreActions(element, parent)) {
      return _isPreActionOfFlutter(element);
    }

    final children = element.children
        .where((node) => node is! XmlText || node.value.trim().isNotEmpty)
        .toList();

    return element.attributes.isEmpty &&
        children.isNotEmpty &&
        children.every(
          (node) =>
              node is XmlElement &&
              SchemeEditor._isPrepareAction(node, targets),
        );
  }

  bool _isBuildPreActions(XmlElement element, XmlElement parent) =>
      element.name.local == 'PreActions' &&
      parent.name.local == 'BuildAction' &&
      identical(parent.parent, root);

  bool _isPreActionOfFlutter(XmlElement element) {
    final container = element.parent;

    return container is XmlElement &&
        container.name.local == 'PreActions' &&
        container.parent is XmlElement &&
        _isBuildPreActions(container, container.parent! as XmlElement) &&
        SchemeEditor._isPrepareAction(element, targets);
  }
}
