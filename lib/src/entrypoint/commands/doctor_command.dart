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

import 'package:flutter_flavorizr/src/engine/lock/lock_store.dart';
import 'package:flutter_flavorizr/src/entrypoint/commands/flavorizr_command.dart';
import 'package:flutter_flavorizr/src/entrypoint/exit_codes.dart';
import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:flutter_flavorizr/src/utils/constants.dart';
import 'package:path/path.dart' as p;

/// How bad the outcome of a check is.
enum CheckLevel {
  /// Nothing to do.
  ok,

  /// Worth knowing, flavorizr works anyway.
  warning,

  /// Flavorizr cannot do its job until it is fixed.
  error,
}

/// The outcome of one check of `flavorizr doctor`.
final class Check {
  /// How bad it is.
  final CheckLevel level;

  /// What was checked.
  final String subject;

  /// What was found, and what to do about it when it is not fine.
  final String detail;

  /// Creates an outcome.
  const Check(this.level, this.subject, this.detail);
}

/// `flavorizr doctor`: whether the project and the machine are ready for
/// flavorizr to run.
///
/// It checks the configuration and the lock, the build scripts of Android
/// (Groovy or Kotlin), the layout of the Xcode projects of iOS and macOS, the
/// Pods, and the version of Flutter. It exits with 1 when a check is an error,
/// and with 0 when everything is fine or only worth knowing.
class DoctorCommand extends FlavorizrCommand {
  /// Creates the command.
  DoctorCommand(super.context);

  @override
  String get name => 'doctor';

  @override
  String get description =>
      'Checks the project and the environment: the configuration and the lock, '
      'Groovy or Kotlin build scripts, the Xcode project layout, the Pods and '
      'the version of Flutter. It exits with 1 when a check fails.';

  @override
  Future<int> execute() async {
    final checks = await _checks();

    for (final check in checks) {
      final line = '${check.subject}: ${check.detail}';

      switch (check.level) {
        case CheckLevel.ok:
          output.success(line);
        case CheckLevel.warning:
          output.warn(line);
        case CheckLevel.error:
          output.err(line);
      }
    }

    final errors = checks.where((c) => c.level == CheckLevel.error).length;

    if (errors == 0) {
      output.info('No problem found.');

      return ExitCodes.ok;
    }

    output.err('$errors ${errors == 1 ? 'problem' : 'problems'} found.');

    return ExitCodes.attention;
  }

  bool _exists(String path) =>
      FileSystemEntity.typeSync(p.join(context.projectRoot.path, path)) !=
      FileSystemEntityType.notFound;

  Future<List<Check>> _checks() async {
    final config = _config();

    return [
      _pubspec(),
      config.$2,
      await _lock(),
      ..._android(config.$1),
      ..._darwin('ios', config.$1?.iosFlavorsAvailable),
      ..._darwin('macos', config.$1?.macosFlavorsAvailable),
      await _flutter(),
    ];
  }

  Check _pubspec() => _exists('pubspec.yaml')
      ? const Check(CheckLevel.ok, 'Project', 'pubspec.yaml found')
      : const Check(
          CheckLevel.error,
          'Project',
          'pubspec.yaml not found: run flavorizr from the root of the project',
        );

  (FlavorizrConfig?, Check) _config() {
    try {
      final config = loadConfig();
      final names = config.flavors.keys.join(', ');

      return (
        config,
        Check(
          CheckLevel.ok,
          'Configuration',
          '${config.flavors.length} '
              '${config.flavors.length == 1 ? 'flavor' : 'flavors'} ($names)',
        ),
      );
    } on CommandFailure catch (failure) {
      return (null, Check(CheckLevel.error, 'Configuration', failure.message));
    }
  }

  Future<Check> _lock() async {
    try {
      final lock = await LockStore(
        context.projectRoot,
        runningVersion: context.version,
      ).read();

      return Check(
        CheckLevel.ok,
        'Lock',
        lock == null
            ? 'no flavorizr.lock yet: it is written by the first apply'
            : 'flavorizr.lock written by flutter_flavorizr '
                  '${lock.flavorizrVersion}',
      );
    } on Object catch (error) {
      return Check(CheckLevel.error, 'Lock', '$error');
    }
  }

  List<Check> _android(FlavorizrConfig? config) {
    final configured = config?.androidFlavorsAvailable ?? false;
    final groovy = _exists(K.androidBuildLegacyPath);
    final kotlin = _exists(K.androidBuildKotlinPath);

    if (!groovy && !kotlin) {
      return [
        if (configured)
          const Check(
            CheckLevel.error,
            'Android',
            'neither android/app/build.gradle nor android/app/build.gradle.kts '
                'exists, so flavors cannot be added',
          ),
      ];
    }

    return [
      if (groovy && kotlin)
        const Check(
          CheckLevel.warning,
          'Android',
          'both build.gradle (Groovy) and build.gradle.kts (Kotlin) exist: '
              'flavorizr follows the Groovy one, remove the one you do not use',
        )
      else
        Check(
          CheckLevel.ok,
          'Android',
          groovy
              ? 'build scripts in Groovy (build.gradle)'
              : 'build scripts in Kotlin (build.gradle.kts)',
        ),
    ];
  }

  List<Check> _darwin(String platform, bool? configured) {
    if (!_exists(platform)) {
      return [
        if (configured ?? false)
          Check(
            CheckLevel.error,
            platform,
            'flavors are configured but the `$platform` folder does not exist',
          ),
      ];
    }

    final project = '$platform/Runner.xcodeproj/project.pbxproj';
    final workspace = '$platform/Runner.xcworkspace';

    return [
      if (_exists(project) && _exists(workspace))
        Check(
          CheckLevel.ok,
          'Xcode ($platform)',
          'Runner.xcodeproj and Runner.xcworkspace found',
        )
      else if (_exists(project))
        Check(
          CheckLevel.warning,
          'Xcode ($platform)',
          'Runner.xcworkspace is missing: run `flutter create .` to restore it',
        )
      else
        Check(
          CheckLevel.error,
          'Xcode ($platform)',
          '$project not found: flavorizr expects the Runner project of Flutter',
        ),
      if (_exists('$platform/Podfile'))
        Check(
          _exists('$platform/Pods') ? CheckLevel.ok : CheckLevel.warning,
          'Pods ($platform)',
          _exists('$platform/Pods')
              ? 'installed'
              : 'not installed: run `pod install` in `$platform` after '
                    'flavorizr',
        ),
    ];
  }

  Future<Check> _flutter() async {
    final version = await context.flutterVersion();

    return version == null
        ? const Check(
            CheckLevel.warning,
            'Flutter',
            'not found: put `flutter` in the PATH to build the flavors',
          )
        : Check(CheckLevel.ok, 'Flutter', version);
  }
}
