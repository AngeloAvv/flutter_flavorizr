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

/// What Flutter does to a scheme when Swift Package Manager is enabled: it
/// adds the "prepare" pre-action in front of the build entries, as text and
/// with its own indentation (`_migrateScheme` of
/// `swift_package_manager_integration_migration.dart` in `flutter_tools`), and
/// it leaves a scheme that has one already (`xcode_backend.sh`) alone.
String withFlutterPreAction(String scheme, {String platform = 'ios'}) {
  if (scheme.contains('xcode_backend.sh') ||
      scheme.contains('macos_assemble.sh')) {
    return scheme;
  }

  String attribute(String name) =>
      RegExp('$name = "([^"]*)"').firstMatch(scheme)!.group(1)!;

  final script = platform == 'ios'
      ? r'scriptText = "/bin/sh &quot;$FLUTTER_ROOT/packages/flutter_tools/bin/xcode_backend.sh&quot; prepare&#10;">'
      : r'scriptText = "&quot;$FLUTTER_ROOT&quot;/packages/flutter_tools/bin/macos_assemble.sh prepare&#10;">';
  final action =
      '''
         <ExecutionAction
            ActionType = "Xcode.IDEStandardExecutionActionsCore.ExecutionActionType.ShellScriptAction">
            <ActionContent
               title = "Run Prepare Flutter Framework Script"
               $script
               <EnvironmentBuildable>
                  <BuildableReference
                     BuildableIdentifier = "primary"
                     BlueprintIdentifier = "${attribute('BlueprintIdentifier')}"
                     BuildableName = "${attribute('BuildableName')}"
                     BlueprintName = "${attribute('BlueprintName')}"
                     ReferencedContainer = "${attribute('ReferencedContainer')}">
                  </BuildableReference>
               </EnvironmentBuildable>
            </ActionContent>
         </ExecutionAction>''';

  if (scheme.contains('PreActions')) {
    return scheme.replaceFirst('<PreActions>', '<PreActions>\n$action');
  }

  const entries = '      <BuildActionEntries>';

  return scheme.replaceFirst(
    entries,
    '      <PreActions>\n$action\n      </PreActions>\n$entries',
  );
}
