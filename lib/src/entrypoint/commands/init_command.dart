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

import 'package:flutter_flavorizr/src/entrypoint/commands/flavorizr_command.dart';
import 'package:flutter_flavorizr/src/entrypoint/exit_codes.dart';
import 'package:path/path.dart' as p;

/// The file `flavorizr init` writes.
const _configFile = 'flavorizr.yaml';

/// The platforms a Flutter project may have, with the key that tells the
/// identifier of an app on it.
const _platforms = {
  'android': 'applicationId',
  'ios': 'bundleId',
  'macos': 'bundleId',
  'linux': 'applicationId',
  'windows': null,
};

/// The name of a flavor: Android takes it as the name of a source set.
final _flavorName = RegExp(r'^[a-z][A-Za-z0-9]*$');

/// `flavorizr init`: writes the `flavorizr.yaml` of a project that has none.
///
/// It finds the platforms the project has, asks for the flavors, the
/// identifier they build on and the name of each app, and writes a
/// configuration with a flavor for each platform. On a project that `flutter
/// create` has just made it offers the `flutter:scaffold` recipe, which writes
/// the Flutter code that uses the flavors. With `--yes` it asks nothing and
/// takes the defaults, which is what a script wants.
class InitCommand extends FlavorizrCommand {
  /// Creates the command.
  InitCommand(super.context) {
    argParser
      ..addOption(
        'flavors',
        help: 'The names of the flavors, separated by commas.',
        valueHelp: 'dev,prod',
      )
      ..addOption(
        'id',
        help:
            'The identifier the apps are built on: the one of a flavor is '
            'this and the name of the flavor.',
        valueHelp: 'com.example.app',
      )
      ..addFlag(
        'scaffold',
        help:
            'Adds the flutter:scaffold recipe, which writes the Flutter code '
            'that uses the flavors. Asked on a new project, by default.',
      )
      ..addFlag(
        'yes',
        abbr: 'y',
        negatable: false,
        help: 'Asks nothing: takes the defaults for what is not an option.',
      )
      ..addFlag(
        'force',
        negatable: false,
        help: 'Replaces a $_configFile that exists.',
      );
  }

  @override
  String get name => 'init';

  @override
  String get description =>
      'Writes flavorizr.yaml: finds the platforms of the project and asks for '
      'the flavors, their identifiers and the names of their apps.';

  @override
  Future<int> execute() async {
    final root = context.projectRoot;

    if (!File(p.join(root.path, 'pubspec.yaml')).existsSync()) {
      throw CommandFailure(
        ExitCodes.usage,
        'pubspec.yaml not found: run flavorizr from the root of a Flutter '
        'project.',
      );
    }

    final file = File(p.join(root.path, _configFile));

    if (file.existsSync() && argResults!['force'] != true) {
      throw CommandFailure(
        ExitCodes.attention,
        '$_configFile exists already: edit it, or run init with --force to '
        'replace it.',
      );
    }

    final platforms = [
      for (final platform in _platforms.keys)
        if (Directory(p.join(root.path, platform)).existsSync()) platform,
    ];

    if (platforms.isEmpty) {
      throw CommandFailure(
        ExitCodes.usage,
        'No platform folder found (android, ios, macos, linux or windows): '
        'run flavorizr from the root of a Flutter project.',
      );
    }

    final yes = argResults!['yes'] == true;
    final project = _projectName();

    output.info('Platforms: ${platforms.join(', ')}');

    final flavors = await _flavors(yes: yes);
    final id = await _id(project, yes: yes);
    final names = <String, String>{
      for (final flavor in flavors)
        flavor: await _appName(project, flavor, yes: yes),
    };
    final scaffold = await _scaffold(yes: yes);

    file.writeAsStringSync(
      _yaml(platforms: platforms, flavors: names, id: id, scaffold: scaffold),
    );

    // What was written has to be something the other commands accept.
    loadConfig();

    output.success('Wrote $_configFile for ${flavors.join(', ')}.');
    output.info(
      'Next: flavorizr plan, to see what would change, and flavorizr apply.',
    );

    return ExitCodes.ok;
  }

  /// The name of the project, from `pubspec.yaml`, or `app`.
  String _projectName() {
    final pubspec = File(p.join(context.projectRoot.path, 'pubspec.yaml'));
    final match = RegExp(
      r'^name:\s*([A-Za-z0-9_]+)',
      multiLine: true,
    ).firstMatch(pubspec.readAsStringSync());

    return match?.group(1) ?? 'app';
  }

  Future<List<String>> _flavors({required bool yes}) async {
    final given = argResults!['flavors'] as String?;
    var answer = given ?? (yes ? null : await _ask('Flavors', 'dev,prod'));

    answer ??= 'dev,prod';

    while (true) {
      final flavors = [
        for (final flavor in answer!.split(','))
          if (flavor.trim().isNotEmpty) flavor.trim(),
      ];
      final invalid = [
        for (final flavor in flavors)
          if (!_flavorName.hasMatch(flavor)) flavor,
      ];
      final duplicated = flavors.length != flavors.toSet().length;

      if (flavors.isNotEmpty && invalid.isEmpty && !duplicated) return flavors;

      final reason = flavors.isEmpty
          ? 'There must be a flavor.'
          : invalid.isNotEmpty
          ? 'A flavor starts with a lowercase letter and has only letters and '
                'digits: ${invalid.join(', ')}.'
          : 'A flavor is named once.';

      if (given != null || yes || !context.environment.interactive) {
        throw CommandFailure(ExitCodes.usage, reason);
      }

      output.err(reason);
      answer = await _ask('Flavors', 'dev,prod');
    }
  }

  Future<String> _id(String project, {required bool yes}) async {
    final given = argResults!['id'] as String?;
    final fallback = 'com.example.${project.replaceAll('_', '')}';

    final id =
        given ?? (yes ? fallback : await _ask('Application id', fallback));

    if (!RegExp(
      r'^[A-Za-z][A-Za-z0-9]*(\.[A-Za-z][A-Za-z0-9]*)+$',
    ).hasMatch(id)) {
      throw CommandFailure(
        ExitCodes.usage,
        'The identifier `$id` must be a reverse domain name of letters and '
        'digits, such as com.example.app.',
      );
    }

    return id;
  }

  Future<String> _appName(
    String project,
    String flavor, {
    required bool yes,
  }) async {
    final fallback =
        '${_title(project)} ${flavor[0].toUpperCase()}${flavor.substring(1)}';

    return yes ? fallback : await _ask('Name of the app of $flavor', fallback);
  }

  /// Whether to add the `flutter:scaffold` recipe.
  Future<bool> _scaffold({required bool yes}) async {
    if (argResults!.wasParsed('scaffold')) {
      return argResults!['scaffold'] == true;
    }

    final main = File(p.join(context.projectRoot.path, 'lib', 'main.dart'));
    final fresh =
        main.existsSync() && main.readAsStringSync().contains('MyHomePage');

    if (!fresh || yes) return false;

    return context.confirm(
      'This looks like a new project: write the Flutter code that uses the '
      'flavors (flutter:scaffold)?',
    );
  }

  Future<String> _ask(String question, String fallback) =>
      context.prompt(question, defaultValue: fallback);

  /// `my_app` as `My App`.
  static String _title(String project) => [
    for (final word in project.split('_'))
      if (word.isNotEmpty) '${word[0].toUpperCase()}${word.substring(1)}',
  ].join(' ');

  static String _quote(String text) =>
      '"${text.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';

  static String _yaml({
    required List<String> platforms,
    required Map<String, String> flavors,
    required String id,
    required bool scaffold,
  }) {
    final lines = [
      '# The flavors of the app: see https://github.com/AngeloAvv/flutter_flavorizr',
      'flavors:',
      for (final MapEntry(key: flavor, value: name) in flavors.entries) ...[
        '  $flavor:',
        '    app:',
        '      name: ${_quote(name)}',
        for (final platform in platforms)
          if (_platforms[platform] case final key?) ...[
            '    $platform:',
            '      $key: ${_quote('$id.$flavor')}',
          ] else
            '    $platform: {}',
      ],
      if (scaffold) ...[
        '',
        '# The default recipe: everything, and the Flutter code that uses the',
        '# flavors, which is written once and then left to you.',
        'recipes:',
        '  start:',
        '    - all',
        '    - flutter:scaffold',
        '  default: start',
      ],
    ];

    return '${lines.join('\n')}\n';
  }
}
